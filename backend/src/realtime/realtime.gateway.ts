import { randomUUID } from 'node:crypto';
import type { IncomingMessage } from 'node:http';
import { Injectable, OnModuleDestroy, Optional } from '@nestjs/common';
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
  REALTIME_MAX_VOICE_FRAMES_PER_WINDOW,
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
import { BookingCall } from '../bookings/domain/booking-call.entity';
import { BookingProjectionService } from './booking-projection.service';
import { RealtimeNotificationPublisher } from './realtime-notification-publisher.service';
import { mapBounded } from '../common/run-bounded';

/**
 * BUG-026. Concurrent session re-checks.
 *
 * An implementation bound: enough that a fleet of connections does not serialise
 * into a visible delay, low enough that a re-check burst cannot become the
 * query load it was added to avoid.
 */
const SESSION_REVALIDATION_CONCURRENCY = 10;

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
    @Optional()
    private readonly events?: RealtimeNotificationPublisher,
  ) {}

  afterInit(): void {
    this.heartbeatTimer = setInterval(() => {
      this.checkHeartbeats();
      // BUG-026. On the same cadence as the heartbeat, because that is already
      // the moment the gateway walks every connection - so the re-check costs a
      // second loop over a list the loop is building anyway, and a socket that
      // is not sending pings is not one that needs watching.
      void this.revalidateSessions().catch(() => undefined);
    }, REALTIME_HEARTBEAT_INTERVAL_MS);
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

  /**
   * Entry point for every inbound socket frame.
   *
   * Public so the gateway specs can drive real frames through the real handler
   * instead of asserting on internals. Nest only wires up methods carrying
   * `@SubscribeMessage`, so widening this does not expose it on the network.
   */
  async onMessage(
    client: WebSocket,
    data: RawData,
    isBinary: boolean,
  ): Promise<void> {
    const state = this.registry.get(client);
    if (!state) return;
    if (isBinary) {
      this.telemetry.increment('messages.invalid');
      client.close(REALTIME_CLOSE.policyViolation, 'text-frames-only');
      return;
    }
    const message = this.parseMessage(data);
    if (!message) {
      this.telemetry.increment('messages.invalid');
      this.send(client, { type: 'error', code: 'invalid-message' });
      return;
    }
    const isVoice = message.type === 'call.voice-frame.v1';
    if (!this.withinMessageLimit(state, isVoice)) {
      this.telemetry.increment('limits.exceeded');
      client.close(
        REALTIME_CLOSE.limitExceeded,
        isVoice ? 'voice-rate-limit' : 'message-rate-limit',
      );
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
    // PERF-005. A liveness probe with no side effects, so a client waking from
    // suspension can tell a live session from a socket the server already
    // terminated while the client was frozen. Deliberately not piggybacked on
    // presence or location: those change state, and a probe that mutates state
    // is a probe that can be wrong in a way nobody can undo.
    if (message.type === 'ping') {
      this.pong(client, message);
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
    if (message.type === 'call.voice-frame.v1') {
      await this.relayVoiceFrame(client, message);
      return;
    }
    this.telemetry.increment('messages.invalid');
    this.send(client, {
      type: 'error',
      requestId: message.requestId,
      code: 'unsupported-message',
    });
  }

  private async relayVoiceFrame(
    senderClient: WebSocket,
    message: RealtimeClientMessage,
  ): Promise<void> {
    const bookingId = message.bookingId;
    const callId = message.callId;
    const data = message.data;
    const senderState = this.registry.get(senderClient);
    const senderId = senderState?.principal?.userId;
    if (!bookingId || !callId || !data || !senderId) return;
    const senderSubscribed = [...senderState.subscriptions.values()].some(
      (subscription) =>
        subscription.channel === 'booking' &&
        subscription.resourceId?.toLowerCase() === bookingId.toLowerCase(),
    );
    if (!senderSubscribed) return;
    const call = await this.dataSource.getRepository(BookingCall).findOneBy({
      id: callId,
      bookingId,
    });
    if (
      !call ||
      call.status !== 'CONNECTED' ||
      ![call.callerUserId, call.calleeUserId].includes(senderId)
    ) {
      return;
    }
    const participants = new Set([call.callerUserId, call.calleeUserId]);
    const frame = {
      type: 'call.voice-frame.v1',
      bookingId,
      callId,
      data,
    };
    if (this.events) {
      await this.events.publishParticipantFrame(
        bookingId,
        [...participants],
        frame,
      );
      return;
    }
    for (const [client, state] of this.registry.entries()) {
      if (client === senderClient || client.readyState !== WebSocket.OPEN)
        continue;
      if (!state.principal?.userId || !participants.has(state.principal.userId))
        continue;
      const subscribed = [...state.subscriptions.values()].some(
        (subscription) =>
          subscription.channel === 'booking' &&
          subscription.resourceId?.toLowerCase() === bookingId.toLowerCase(),
      );
      if (!subscribed) continue;
      client.send(JSON.stringify(frame));
    }
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
    let booking: Booking | null = null;
    try {
      if (message.channel === 'account') {
        await this.authorization.authorizeAccessToken(
          state.accessToken,
          PERMISSIONS.realtimeSubscribeSelf,
          { ownerId: message.resourceId },
        );
      } else {
        booking = await this.dataSource
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
      if (message.channel === 'booking' && booking) {
        try {
          const latest = await this.location.getLatestAuthorized(
            state.principal,
            booking.id,
          );
          if (latest) {
            await this.projections.publishLocation(booking, latest);
          }
        } catch {
          // Best effort initial location projection
        }
      }
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

  /**
   * PERF-005. Answers a liveness probe.
   *
   * Reaching this handler already proves the session is authenticated and the
   * server is serving it, which is the whole point - a socket the gateway
   * terminated for missed pongs will never get here. The `serverTime` is sent
   * back so the client can measure the round trip rather than only infer
   * liveness from the fact that something arrived.
   */
  private pong(client: WebSocket, message: RealtimeClientMessage): void {
    this.telemetry.increment('messages.ping');
    this.send(client, {
      type: 'pong',
      requestId: message.requestId,
      serverTime: Date.now(),
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

  /**
   * BUG-026. Re-checks sessions that have gone unconfirmed.
   *
   * The access token was verified once, at `authenticate`, and
   * `auth_sessions.expires_at` / `revoked_at` were never read again. So a
   * revoked session - or a suspended user - kept an open socket receiving
   * booking state, chat and voice signalling for the life of the process, which
   * on a provider's always-on socket is days. Every HTTP request in this system
   * re-reads the user row and the role set per request, and the realtime channel
   * was the one place a revocation did not apply.
   *
   * The re-check goes through the same `authorizeAccessToken` the connect path
   * uses, so it also catches a suspended account and an expired token, not only
   * an explicit revocation - one code path, one set of rules.
   *
   * Driven from the heartbeat rather than from every broadcast on purpose: the
   * cost is one query per connection per `REALTIME_SESSION_REVALIDATION_MS`,
   * bounded and predictable, instead of one per frame.
   *
   * A dependency failure closes nothing. If the database is briefly unavailable,
   * dropping every live connection would turn a blip into a total outage of
   * tracking - so an inconclusive check is left inconclusive and retried, and
   * only a definite denial closes the socket.
   */
  async revalidateSessions(now = Date.now()): Promise<number> {
    const due = this.registry.dueForSessionRevalidation(now);
    if (due.length === 0) return 0;

    const results = await mapBounded(
      due.map(({ client, state }) => async () => {
        const token = state.accessToken;
        const principal = state.principal;
        if (!token || !principal) return 'unauthenticated' as const;
        try {
          const refreshed = await this.authorization.authorizeAccessToken(
            token,
            PERMISSIONS.realtimeConnect,
          );
          // A token that now resolves to a different user is not a refresh, it
          // is a substitution. Treated as a denial: the subscriptions on this
          // socket were granted to the previous identity.
          if (refreshed.userId !== principal.userId)
            return 'identity-changed' as const;
          this.registry.markSessionVerified(client, now);
          return 'ok' as const;
        } catch (error) {
          return this.classifyRevalidationFailure(error);
        }
      }),
      SESSION_REVALIDATION_CONCURRENCY,
    );

    let closed = 0;
    for (const [index, outcome] of results.entries()) {
      if (outcome === 'ok') continue;
      const { client } = due[index];
      const knownDenial =
        outcome === 'revoked' ||
        outcome === 'identity-changed' ||
        outcome === 'unauthenticated';
      if (knownDenial) {
        this.telemetry.increment('session.revoked');
        client.close(REALTIME_CLOSE.sessionRevoked, 'session-no-longer-valid');
        this.registry.remove(client);
        closed += 1;
        continue;
      }
      // Inconclusive. The connection stays, and the next heartbeat tries again.
      this.telemetry.increment('session.revalidation.deferred');
    }
    return closed;
  }

  /**
   * Separates "this session is not valid" from "we could not find out".
   *
   * Conflating them is the dangerous mistake: treating a database timeout as a
   * revocation disconnects every provider on the platform during a blip, and
   * treating a revocation as inconclusive means a revoked session never gets
   * closed at all - which is the bug this whole mechanism exists to fix.
   */
  private classifyRevalidationFailure(error: unknown): 'revoked' | 'deferred' {
    const name = error instanceof Error ? error.constructor.name : '';
    if (name === 'UnauthorizedException' || name === 'ForbiddenException') {
      return 'revoked';
    }
    return 'deferred';
  }

  private withinMessageLimit(
    state: {
      messageWindowStartedAt: number;
      messageCount: number;
      voiceWindowStartedAt?: number;
      voiceMessageCount?: number;
    },
    isVoice = false,
  ): boolean {
    const now = Date.now();
    if (isVoice) {
      if (
        !state.voiceWindowStartedAt ||
        now - state.voiceWindowStartedAt >= REALTIME_MESSAGE_WINDOW_MS
      ) {
        state.voiceWindowStartedAt = now;
        state.voiceMessageCount = 0;
      }
      state.voiceMessageCount = (state.voiceMessageCount ?? 0) + 1;
      return state.voiceMessageCount <= REALTIME_MAX_VOICE_FRAMES_PER_WINDOW;
    }

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
        'messageText',
        'clientMessageId',
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
    // Browser sockets always send Origin; native clients do not. In
    // development any local port is trusted because `flutter run -d chrome`
    // serves from a random port each run. Production relies on the strict
    // REALTIME_ALLOWED_ORIGINS allowlist.
    if (this.config.get<string>('NODE_ENV') === 'development') {
      return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
    }
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
