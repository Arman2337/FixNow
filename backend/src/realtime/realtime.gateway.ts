import { randomUUID } from 'node:crypto';
import type { IncomingMessage } from 'node:http';
import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { WebSocket } from 'ws';
import type { RawData, Server } from 'ws';
import { AuthorizationService } from '../common/authorization/authorization.service';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import {
  REALTIME_AUTH_TIMEOUT_MS,
  REALTIME_CLOSE,
  REALTIME_HEARTBEAT_INTERVAL_MS,
  REALTIME_MAX_MESSAGES_PER_WINDOW,
  REALTIME_MAX_PAYLOAD_BYTES,
  REALTIME_MAX_SUBSCRIPTIONS,
  REALTIME_MESSAGE_WINDOW_MS,
  REALTIME_PATH,
  REALTIME_PROTOCOL_VERSION,
} from './realtime.constants';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import { RealtimeTelemetryService } from './realtime-telemetry.service';
import type { RealtimeClientMessage } from './realtime.types';
import { LocationService } from '../location/location.service';
import { DataSource } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingProjectionService } from './booking-projection.service';

@Injectable()
@WebSocketGateway({
  path: REALTIME_PATH,
  maxPayload: REALTIME_MAX_PAYLOAD_BYTES,
  perMessageDeflate: false,
})
export class RealtimeGateway
  implements
    OnGatewayInit,
    OnGatewayConnection,
    OnGatewayDisconnect,
    OnModuleDestroy
{
  @WebSocketServer() server: Server;
  private heartbeatTimer?: NodeJS.Timeout;

  constructor(
    private readonly authorization: AuthorizationService,
    private readonly registry: RealtimeConnectionRegistry,
    private readonly telemetry: RealtimeTelemetryService,
    private readonly config: ConfigService,
    private readonly location: LocationService,
    private readonly dataSource: DataSource,
    private readonly projections: BookingProjectionService,
  ) {}

  afterInit(): void {
    this.heartbeatTimer = setInterval(
      () => this.checkHeartbeats(),
      REALTIME_HEARTBEAT_INTERVAL_MS,
    );
    this.heartbeatTimer.unref();
  }

  handleConnection(client: WebSocket, request: IncomingMessage): void {
    const address = request.socket.remoteAddress ?? 'unknown';
    if (!this.originAllowed(request.headers.origin)) {
      this.telemetry.increment('connections.denied');
      client.close(REALTIME_CLOSE.accessDenied, 'origin-not-allowed');
      return;
    }
    if (!this.registry.registerPending(client, address)) {
      this.telemetry.increment('limits.exceeded');
      client.close(REALTIME_CLOSE.limitExceeded, 'connection-limit');
      return;
    }
    this.telemetry.increment('connections.accepted');
    const state = this.registry.get(client);
    if (!state) return;
    state.authTimer = setTimeout(() => {
      if (!state.principal) {
        this.telemetry.increment('authentication.denied');
        client.close(
          REALTIME_CLOSE.authenticationRequired,
          'authentication-timeout',
        );
      }
    }, REALTIME_AUTH_TIMEOUT_MS);
    state.authTimer.unref();
    client.on('pong', () => {
      const current = this.registry.get(client);
      if (current) current.alive = true;
    });
    client.on('message', (data, isBinary) => {
      void this.onMessage(client, data, isBinary);
    });
  }

  handleDisconnect(client: WebSocket): void {
    this.registry.remove(client);
    this.telemetry.increment('connections.closed');
  }

  onModuleDestroy(): void {
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
    for (const [client] of this.registry.entries()) {
      client.close(1012, 'server-restart');
      this.registry.remove(client);
    }
  }

  private async onMessage(
    client: WebSocket,
    data: RawData,
    isBinary: boolean,
  ): Promise<void> {
    const state = this.registry.get(client);
    if (!state) return;
    if (isBinary || !this.withinMessageLimit(state)) {
      this.telemetry.increment(
        isBinary ? 'messages.invalid' : 'limits.exceeded',
      );
      client.close(
        isBinary
          ? REALTIME_CLOSE.policyViolation
          : REALTIME_CLOSE.limitExceeded,
        isBinary ? 'text-frames-only' : 'message-rate-limit',
      );
      return;
    }
    const message = this.parseMessage(data);
    if (!message) {
      this.telemetry.increment('messages.invalid');
      this.send(client, { type: 'error', code: 'invalid-message' });
      return;
    }
    if (!state.principal) {
      if (message.type !== 'authenticate') {
        client.close(
          REALTIME_CLOSE.authenticationRequired,
          'authentication-required',
        );
        return;
      }
      await this.authenticate(client, message);
      return;
    }
    if (message.type === 'subscribe') {
      await this.subscribe(client, message);
      return;
    }
    if (message.type === 'unsubscribe') {
      this.unsubscribe(client, message);
      return;
    }
    if (message.type === 'presence-update') {
      await this.updatePresence(client, message);
      return;
    }
    if (message.type === 'location-consent') {
      await this.updateLocationConsent(client, message);
      return;
    }
    if (message.type === 'location-update') {
      await this.ingestLocation(client, message);
      return;
    }
    this.telemetry.increment('messages.invalid');
    this.send(client, {
      type: 'error',
      requestId: message.requestId,
      code: 'unsupported-message',
    });
  }

  private async authenticate(
    client: WebSocket,
    message: RealtimeClientMessage,
  ): Promise<void> {
    if (!message.accessToken || message.accessToken.length > 4096) {
      client.close(
        REALTIME_CLOSE.authenticationRequired,
        'authentication-required',
      );
      return;
    }
    try {
      const principal = await this.authorization.authorizeAccessToken(
        message.accessToken,
        PERMISSIONS.realtimeConnect,
      );
      if (!this.registry.authenticate(client, principal, message.accessToken)) {
        this.telemetry.increment('limits.exceeded');
        client.close(REALTIME_CLOSE.limitExceeded, 'connection-limit');
        return;
      }
      const state = this.registry.get(client);
      if (state?.authTimer) clearTimeout(state.authTimer);
      this.telemetry.increment('authentication.allowed');
      this.send(client, {
        type: 'ready',
        connectionId: randomUUID(),
        protocolVersion: REALTIME_PROTOCOL_VERSION,
        heartbeatIntervalMs: REALTIME_HEARTBEAT_INTERVAL_MS,
        maxSubscriptions: REALTIME_MAX_SUBSCRIPTIONS,
        maxPayloadBytes: REALTIME_MAX_PAYLOAD_BYTES,
        resumeSupported: false,
      });
    } catch (error) {
      const knownDenial =
        error instanceof Error &&
        ['UnauthorizedException', 'ForbiddenException'].includes(
          error.constructor.name,
        );
      this.telemetry.increment(
        knownDenial ? 'authentication.denied' : 'dependency.failure',
      );
      client.close(
        knownDenial
          ? REALTIME_CLOSE.authenticationRequired
          : REALTIME_CLOSE.dependencyUnavailable,
        knownDenial ? 'authentication-required' : 'temporarily-unavailable',
      );
    }
  }

  private async subscribe(
    client: WebSocket,
    message: RealtimeClientMessage,
  ): Promise<void> {
    const state = this.registry.get(client);
    if (!state?.principal || !state.accessToken) return;
    if (
      !['account', 'booking'].includes(message.channel ?? '') ||
      !message.resourceId ||
      !this.isUuid(message.resourceId)
    ) {
      this.denySubscription(client, message.requestId, 'not-authorized');
      return;
    }
    if (state.subscriptions.size >= REALTIME_MAX_SUBSCRIPTIONS) {
      this.telemetry.increment('limits.exceeded');
      this.denySubscription(client, message.requestId, 'limit-exceeded');
      return;
    }
    try {
      if (message.channel === 'account') {
        await this.authorization.authorizeAccessToken(
          state.accessToken,
          PERMISSIONS.realtimeSubscribeSelf,
          { ownerId: message.resourceId },
        );
      } else {
        const booking = await this.dataSource
          .getRepository(Booking)
          .findOne({ where: { id: message.resourceId } });
        if (
          !booking ||
          (booking.customerId !== state.principal.userId &&
            booking.providerId !== state.principal.userId)
        )
          throw new Error('not-authorized');
      }
      const id = randomUUID();
      state.subscriptions.set(id, {
        id,
        channel: message.channel as 'account' | 'booking',
        resourceId: message.resourceId,
      });
      this.telemetry.increment('subscriptions.allowed');
      this.send(client, {
        type: 'subscribed',
        requestId: message.requestId,
        subscriptionId: id,
        channel: message.channel,
        resourceId: message.resourceId,
        recovery:
          message.afterSequence === undefined
            ? 'snapshot-current'
            : 'snapshot-required',
      });
    } catch {
      this.denySubscription(client, message.requestId, 'not-authorized');
    }
  }

  private denySubscription(
    client: WebSocket,
    requestId: string | undefined,
    code: string,
  ): void {
    this.telemetry.increment('subscriptions.denied');
    this.send(client, {
      type: 'subscription-denied',
      requestId,
      code,
    });
  }

  private unsubscribe(client: WebSocket, message: RealtimeClientMessage): void {
    const state = this.registry.get(client);
    const removed = message.subscriptionId
      ? state?.subscriptions.delete(message.subscriptionId)
      : false;
    this.send(client, {
      type: 'unsubscribed',
      requestId: message.requestId,
      removed: removed ?? false,
    });
  }

  private async updatePresence(
    client: WebSocket,
    message: RealtimeClientMessage,
  ): Promise<void> {
    const principal = this.registry.get(client)?.principal;
    if (!principal) return;
    try {
      const result = await this.location.updatePresence(principal, {
        online: message.online as boolean,
      });
      this.send(client, {
        type: 'presence-ack',
        requestId: message.requestId,
        ...result,
      });
    } catch (error) {
      this.locationDenied(client, message.requestId, error);
    }
  }

  private async updateLocationConsent(
    client: WebSocket,
    message: RealtimeClientMessage,
  ): Promise<void> {
    const principal = this.registry.get(client)?.principal;
    if (!principal) return;
    try {
      const result = await this.location.updateConsent(principal, {
        bookingId: message.bookingId as string,
        granted: message.granted as boolean,
        noticeVersion: message.noticeVersion as string,
      });
      this.send(client, {
        type: 'location-consent-ack',
        requestId: message.requestId,
        ...result,
      });
    } catch (error) {
      this.locationDenied(client, message.requestId, error);
    }
  }

  private async ingestLocation(
    client: WebSocket,
    message: RealtimeClientMessage,
  ): Promise<void> {
    const principal = this.registry.get(client)?.principal;
    if (!principal) return;
    try {
      const result = await this.location.ingestLocation(principal, {
        bookingId: message.bookingId as string,
        sequence: message.sequence as number,
        capturedAt: message.capturedAt as string,
        latitude: message.latitude as number,
        longitude: message.longitude as number,
        accuracyMeters: message.accuracyMeters as number,
      });
      const booking = await this.dataSource
        .getRepository(Booking)
        .findOne({ where: { id: message.bookingId } });
      const latest = await this.location.getLatestAuthorized(
        principal,
        message.bookingId as string,
      );
      if (booking && latest) {
        await this.projections.publishLocation(booking, latest);
      }
      this.send(client, {
        type: 'location-ack',
        requestId: message.requestId,
        ...result,
      });
    } catch (error) {
      this.locationDenied(client, message.requestId, error);
    }
  }

  private locationDenied(
    client: WebSocket,
    requestId: string | undefined,
    error: unknown,
  ): void {
    const name = error instanceof Error ? error.constructor.name : '';
    const code =
      name === 'BadRequestException'
        ? 'invalid-location'
        : name === 'ConflictException'
          ? 'stale-or-rate-limited'
          : 'not-authorized';
    this.telemetry.increment('location.denied');
    this.send(client, { type: 'location-denied', requestId, code });
  }

  checkHeartbeats(): void {
    for (const [client, state] of this.registry.entries()) {
      if (client.readyState !== WebSocket.OPEN) continue;
      if (!state.alive) {
        this.telemetry.increment('heartbeat.timeout');
        client.terminate();
        this.registry.remove(client);
        continue;
      }
      state.alive = false;
      client.ping();
    }
  }

  private withinMessageLimit(state: {
    messageWindowStartedAt: number;
    messageCount: number;
  }): boolean {
    const now = Date.now();
    if (now - state.messageWindowStartedAt >= REALTIME_MESSAGE_WINDOW_MS) {
      state.messageWindowStartedAt = now;
      state.messageCount = 0;
    }
    state.messageCount += 1;
    return state.messageCount <= REALTIME_MAX_MESSAGES_PER_WINDOW;
  }

  private parseMessage(data: RawData): RealtimeClientMessage | null {
    try {
      const value: unknown = JSON.parse(this.rawDataText(data));
      if (!value || typeof value !== 'object' || Array.isArray(value))
        return null;
      const record = value as Record<string, unknown>;
      if (typeof record.type !== 'string' || Object.keys(record).length > 10) {
        return null;
      }
      if (
        record.requestId !== undefined &&
        (typeof record.requestId !== 'string' || record.requestId.length > 128)
      ) {
        return null;
      }
      for (const field of [
        'accessToken',
        'channel',
        'resourceId',
        'subscriptionId',
        'bookingId',
        'noticeVersion',
        'capturedAt',
      ] as const) {
        if (record[field] !== undefined && typeof record[field] !== 'string') {
          return null;
        }
      }
      for (const field of [
        'sequence',
        'latitude',
        'longitude',
        'accuracyMeters',
      ] as const) {
        if (record[field] !== undefined && typeof record[field] !== 'number')
          return null;
      }
      for (const field of ['online', 'granted'] as const) {
        if (record[field] !== undefined && typeof record[field] !== 'boolean')
          return null;
      }
      if (
        record.afterSequence !== undefined &&
        (!Number.isSafeInteger(record.afterSequence) ||
          Number(record.afterSequence) < 0)
      ) {
        return null;
      }
      return record as unknown as RealtimeClientMessage;
    } catch {
      return null;
    }
  }

  private originAllowed(origin: string | undefined): boolean {
    if (!origin) return true;
    const configured =
      this.config.get<string>('REALTIME_ALLOWED_ORIGINS') ?? '';
    const allowed = configured
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);
    return allowed.includes(origin);
  }

  private rawDataText(data: RawData): string {
    if (data instanceof ArrayBuffer) return Buffer.from(data).toString('utf8');
    if (Array.isArray(data)) return Buffer.concat(data).toString('utf8');
    return data.toString('utf8');
  }

  private isUuid(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    );
  }

  private send(
    client: WebSocket,
    frame: Readonly<Record<string, unknown>>,
  ): void {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(frame));
    }
  }
}
