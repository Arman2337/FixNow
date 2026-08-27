import { Inject, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Booking } from '../../bookings/domain/booking.entity';
import { BookingStatus } from '../../../../shared/booking-lifecycle.types';
import {
  PUSH_DELIVERY,
  type PushDelivery,
  type PushNotificationContent,
} from '../push/push-delivery';
import { PushDeviceTokenEntity } from '../push/push-device-token.entity';
import {
  NotificationDelivery,
  NotificationDeliveryStatus,
} from './notification-delivery.entity';

/**
 * Lock-screen-safe templates. Booking identifiers and generic wording only —
 * never names, addresses, phone numbers, or other personal data.
 */
export const BOOKING_NOTIFICATION_TEMPLATES: Readonly<
  Record<string, PushNotificationContent>
> = {
  'customer:ASSIGNED': {
    title: 'FixNow',
    body: 'A provider accepted your request.',
  },
  'customer:EN_ROUTE': {
    title: 'FixNow',
    body: 'Your provider is on the way.',
  },
  'customer:IN_PROGRESS': {
    title: 'FixNow',
    body: 'Your service has started.',
  },
  'customer:COMPLETED': {
    title: 'FixNow',
    body: 'Your service was completed. Feedback helps quality.',
  },
  'customer:CANCELLED': {
    title: 'FixNow',
    body: 'Your booking was cancelled.',
  },
  'provider:REQUESTED': {
    title: 'FixNow',
    body: 'A new request is available near you.',
  },
  'provider:CANCELLED': {
    title: 'FixNow',
    body: 'An assigned booking was cancelled.',
  },
  'customer:CHAT_MESSAGE': {
    title: 'FixNow',
    body: 'New message regarding your active service.',
  },
  'provider:CHAT_MESSAGE': {
    title: 'FixNow',
    body: 'New message regarding your assigned service.',
  },
};

/**
 * FN-063 emergency templates (policy §8). Copy approved in
 * docs/safety/emergency-dispatch-policy-v1.md; quiet-hour override applies
 * to these sends only.
 */
export const EMERGENCY_NOTIFICATION_TEMPLATES: Readonly<
  Record<string, PushNotificationContent>
> = {
  'provider:EMERGENCY_REQUEST': {
    title: 'FixNow — Emergency',
    body: 'Emergency request near you — open FixNow.',
  },
};

/**
 * FN-062: in-process domain notification consumer. Sends deduplicated,
 * lock-screen-safe pushes over the FN-061 delivery boundary and records one
 * delivery row per attempt. Push is never the sole source of truth — the
 * realtime projections remain authoritative.
 *
 * ponytail: quiet hours are a server-wide UTC window (NOTIFICATION_QUIET_HOURS_UTC,
 * e.g. "23-7", empty = disabled) because no per-user timezone is captured yet.
 * Per-user local quiet hours and emergency override arrive with FN-063.
 */
@Injectable()
export class DomainNotificationService {
  constructor(
    @InjectRepository(NotificationDelivery)
    private readonly deliveries: Repository<NotificationDelivery>,
    @InjectRepository(PushDeviceTokenEntity)
    private readonly devices: Repository<PushDeviceTokenEntity>,
    @Inject(PUSH_DELIVERY) private readonly delivery: PushDelivery,
  ) {}

  async notifyBookingEvent(
    booking: Booking,
    audience: 'customer' | 'provider',
    status: BookingStatus,
  ): Promise<void> {
    const template = BOOKING_NOTIFICATION_TEMPLATES[`${audience}:${status}`];
    if (!template) return;
    const userId =
      audience === 'customer' ? booking.customerId : booking.providerId;
    if (!userId) return;
    await this.send(
      userId,
      `booking:${audience}:${status}`,
      `booking:${booking.id}:${audience}:${status}`,
      template,
      booking.id,
    );
  }

  /** Fan-out to eligible providers for a freshly created request. */
  async notifyProvidersOfAvailableRequest(
    booking: Booking,
    eligibleProviderIds: string[],
    cap = 20,
  ): Promise<void> {
    const template = BOOKING_NOTIFICATION_TEMPLATES['provider:REQUESTED'];
    if (!template) return;
    for (const providerId of eligibleProviderIds.slice(0, cap)) {
      await this.send(
        providerId,
        'booking:provider:REQUESTED',
        `booking:${booking.id}:provider:REQUESTED`,
        template,
        booking.id,
      );
    }
  }

  /** Notify inactive party of an incoming in-app chat message. */
  async notifyChatMessage(
    booking: Booking,
    recipientUserId: string,
    audience: 'customer' | 'provider',
    messageId: string,
  ): Promise<void> {
    const template = BOOKING_NOTIFICATION_TEMPLATES[`${audience}:CHAT_MESSAGE`];
    if (!template) return;
    await this.send(
      recipientUserId,
      `booking:${audience}:CHAT_MESSAGE`,
      `booking:${booking.id}:chat:${messageId}`,
      template,
      booking.id,
    );
  }

  async send(
    userId: string,
    kind: string,
    dedupeKey: string,
    content: PushNotificationContent,
    bookingId: string | null = null,
    options: { bypassQuietHours?: boolean } = {},
  ): Promise<void> {
    const existing = await this.deliveries.findOneBy({
      userId,
      dedupeKey,
    });
    if (existing) return; // Deduplicated replay.

    if (!options.bypassQuietHours && this.inQuietHours()) {
      await this.record(
        userId,
        kind,
        dedupeKey,
        bookingId,
        NotificationDeliveryStatus.SKIPPED_QUIET_HOURS,
        null,
      );
      return;
    }

    const tokens = await this.devices.find({
      where: { userId, enabled: true },
      select: { token: true },
    });
    if (tokens.length === 0) {
      await this.record(
        userId,
        kind,
        dedupeKey,
        bookingId,
        NotificationDeliveryStatus.NO_DEVICES,
        null,
      );
      return;
    }

    let sentAny = false;
    for (const { token } of tokens) {
      try {
        const result = await this.delivery.sendToToken(token, content);
        if (result.status === 'sent') sentAny = true;
        if (result.status === 'unregistered') {
          // Stale token: drop it so future sends skip the dead device.
          await this.devices.update({ token }, { enabled: false });
        }
      } catch {
        // Single attempt per send; the delivery row records the failure.
      }
    }
    await this.record(
      userId,
      kind,
      dedupeKey,
      bookingId,
      sentAny
        ? NotificationDeliveryStatus.SENT
        : NotificationDeliveryStatus.FAILED,
      null,
    );
  }

  private inQuietHours(): boolean {
    const raw = process.env.NOTIFICATION_QUIET_HOURS_UTC?.trim();
    if (!raw) return false;
    const match = /^(\d{1,2})-(\d{1,2})$/.exec(raw);
    if (!match) return false;
    const start = Number(match[1]);
    const end = Number(match[2]);
    if (start > 23 || end > 23) return false;
    const hour = new Date().getUTCHours();
    return start <= end
      ? hour >= start && hour < end
      : hour >= start || hour < end;
  }

  private async record(
    userId: string,
    kind: string,
    dedupeKey: string,
    bookingId: string | null,
    status: NotificationDeliveryStatus,
    providerMessageId: string | null,
  ): Promise<void> {
    try {
      await this.deliveries.insert(
        this.deliveries.create({
          userId,
          kind,
          dedupeKey,
          bookingId,
          status,
          providerMessageId,
        }),
      );
    } catch {
      // A concurrent identical send won the unique dedupe race; skip quietly.
    }
  }
}
