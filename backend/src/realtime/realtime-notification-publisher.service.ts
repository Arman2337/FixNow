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
      this.publisher = createClient({ url });
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
