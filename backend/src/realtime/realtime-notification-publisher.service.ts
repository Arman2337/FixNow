import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, type RedisClientType } from 'redis';
import { WebSocket } from 'ws';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';

const REALTIME_CHANNEL = 'fixnow:realtime:events';

type RealtimeFrame = Readonly<Record<string, unknown>>;
type RoutedEvent =
  | { kind: 'account'; userId: string; frame: RealtimeFrame }
  | { kind: 'booking'; bookingId: string; frame: RealtimeFrame }
  | {
      kind: 'participants';
      bookingId: string;
      userIds: string[];
      frame: RealtimeFrame;
    };

@Injectable()
export class RealtimeNotificationPublisher
  implements OnModuleInit, OnModuleDestroy
{
  private publisher?: RedisClientType;
  private subscriber?: RedisClientType;

  constructor(
    private readonly registry: RealtimeConnectionRegistry,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    const url = this.config.get<string>('REDIS_URL')?.trim();
    if (!url) return;
    try {
      // Bounded on purpose. node-redis's default reconnect strategy retries
      // forever, so `connect()` against an unreachable Redis never settles: the
      // catch below never runs, `onModuleInit` never resolves, and the whole
      // application hangs on boot instead of degrading. Returning an Error from
      // the strategy is what makes node-redis give up and reject, which is the
      // one thing that lets the intended degradation actually happen.
      // Backoff matches `RedisCacheModule`: grow quickly, cap at 2s, give up
      // after ~10 attempts (~13s worst case) so a transient blip is survived
      // but a genuinely absent Redis cannot hold boot open.
      this.publisher = createClient({
        url,
        socket: {
          connectTimeout: 5000,
          reconnectStrategy: (retries: number) =>
            retries > 10
              ? new Error('redis unreachable')
              : Math.min(retries * 50, 2000),
        },
      });
      this.subscriber = this.publisher.duplicate();
      this.publisher.on('error', () => undefined);
      this.subscriber.on('error', () => undefined);
      await Promise.all([this.publisher.connect(), this.subscriber.connect()]);
      await this.subscriber.subscribe(REALTIME_CHANNEL, (message) => {
        try {
          this.routeEvent(JSON.parse(message) as RoutedEvent);
        } catch {
          return;
        }
      });
    } catch {
      // Degrade, but do not leave anything behind. The reconnect strategy has
      // already stopped, and `disconnect` additionally releases the socket, so
      // no handle from a failed boot is left holding the event loop open - which
      // is what turns a failed connection into a hung test run.
      const halfBuilt = [this.publisher, this.subscriber].filter(
        (client): client is RedisClientType => client !== undefined,
      );
      await Promise.allSettled(
        halfBuilt.map(async (client) => {
          try {
            await client.disconnect();
          } catch {
            // A client whose `connect` never succeeded is already closed, and
            // `disconnect` throws `ClientClosedError` synchronously in that
            // state. It throws rather than rejects, so it escapes
            // `Promise.allSettled` argument evaluation and would reject the
            // boot instead of degrading - which is the outcome this whole block
            // exists to avoid.
          }
        }),
      );
      this.publisher = undefined;
      this.subscriber = undefined;
    }
  }

  async publishAccountNotification(
    userId: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    await this.publishAccountFrame(userId, {
      type: 'notification.created.v1',
      data,
    });
  }

  async publishAccountFrame(
    userId: string,
    frame: RealtimeFrame,
  ): Promise<void> {
    await this.publishEvent({ kind: 'account', userId, frame });
  }

  async publishBookingFrame(
    bookingId: string,
    frame: RealtimeFrame,
  ): Promise<void> {
    await this.publishEvent({ kind: 'booking', bookingId, frame });
  }

  async publishParticipantFrame(
    bookingId: string,
    userIds: string[],
    frame: RealtimeFrame,
  ): Promise<void> {
    await this.publishEvent({
      kind: 'participants',
      bookingId,
      userIds,
      frame,
    });
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.all([
      this.publisher?.quit().catch(() => undefined),
      this.subscriber?.quit().catch(() => undefined),
    ]);
    this.publisher = undefined;
    this.subscriber = undefined;
  }

  private async publishEvent(event: RoutedEvent): Promise<void> {
    if (this.publisher?.isReady) {
      try {
        await this.publisher.publish(REALTIME_CHANNEL, JSON.stringify(event));
        return;
      } catch {
        this.routeEvent(event);
        return;
      }
    }
    this.routeEvent(event);
  }

  private routeEvent(event: RoutedEvent): void {
    if (event.kind === 'account') {
      this.routeAccount(event.userId, event.frame);
      return;
    }
    if (event.kind === 'booking') {
      this.routeBooking(event.bookingId, event.frame);
      return;
    }
    const participants = new Set(event.userIds);
    this.routeParticipants(event.bookingId, participants, event.frame);
  }

  private routeAccount(userId: string, frame: RealtimeFrame): void {
    const payload = JSON.stringify(frame);
    for (const [client, state] of this.registry.entries()) {
      if (!this.isSubscribed(client, state, 'account', userId)) continue;
      if (state.principal?.userId !== userId) continue;
      client.send(payload);
    }
  }

  private routeBooking(bookingId: string, frame: RealtimeFrame): void {
    const payload = JSON.stringify(frame);
    for (const [client, state] of this.registry.entries()) {
      if (!this.isSubscribed(client, state, 'booking', bookingId)) continue;
      client.send(payload);
    }
  }

  private routeParticipants(
    bookingId: string,
    participants: Set<string>,
    frame: RealtimeFrame,
  ): void {
    const payload = JSON.stringify(frame);
    for (const [client, state] of this.registry.entries()) {
      if (!this.isSubscribed(client, state, 'booking', bookingId)) continue;
      if (!state.principal?.userId || !participants.has(state.principal.userId))
        continue;
      client.send(payload);
    }
  }

  private isSubscribed(
    client: WebSocket,
    state: {
      subscriptions: Map<string, { channel: string; resourceId: string }>;
    },
    channel: string,
    resourceId: string,
  ): boolean {
    if (client.readyState !== WebSocket.OPEN) return false;
    return [...state.subscriptions.values()].some(
      (subscription) =>
        subscription.channel === channel &&
        subscription.resourceId.toLowerCase() === resourceId.toLowerCase(),
    );
  }
}
