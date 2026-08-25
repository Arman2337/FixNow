import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { And, In, LessThanOrEqual, MoreThan, Repository } from 'typeorm';
import { Booking } from '../../bookings/domain/booking.entity';
import { BookingStatus } from '../../../../shared/booking-lifecycle.types';
import type { PushNotificationContent } from '../push/push-delivery';
import { DomainNotificationService } from './domain-notification.service';

/** Lock-screen-safe reminder wording; no names, addresses, or amounts. */
export const BOOKING_REMINDER_TEMPLATES: Readonly<
  Record<'customer' | 'provider', PushNotificationContent>
> = {
  customer: {
    title: 'FixNow',
    body: 'Your FixNow service is starting soon.',
  },
  provider: {
    title: 'FixNow',
    body: 'You have an assigned FixNow job starting soon.',
  },
};

const REMINDER_ELIGIBLE_STATUSES = [
  BookingStatus.REQUESTED,
  BookingStatus.ASSIGNED,
];

/** Bound work per tick; the next tick picks up any remainder. */
const SCAN_CAP = 50;

/**
 * FN-062 remainder: scheduled-booking reminders. A plain interval scanner
 * over upcoming bookings feeding the deduplicated send path — no scheduler
 * dependency needed, because the notification_deliveries unique index makes
 * every reminder fire exactly once even across overlapping ticks or
 * multiple instances.
 *
 * ponytail: reminders target one fixed lead window (server-wide) instead of
 * per-user preferences; per-user lead choices arrive if customers ask.
 */
@Injectable()
export class BookingReminderService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @InjectRepository(Booking)
    private readonly bookings: Repository<Booking>,
    private readonly notifications: DomainNotificationService,
  ) {}

  onModuleInit(): void {
    const intervalMs = this.numberEnv(
      'NOTIFICATION_REMINDER_INTERVAL_MS',
      60_000,
    );
    this.timer = setInterval(
      () => {
        void this.scanSafely();
      },
      Math.max(intervalMs, 5_000),
    );
    // Never hold the process open for the sake of a reminder tick.
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /**
   * One scan pass. Public for deterministic testing; `now` is injectable.
   * Sends at most one customer and one provider reminder per booking —
   * dedupe keys `reminder:booking:<id>:<role>` are permanent.
   */
  async scanOnce(now = new Date()): Promise<number> {
    const leadMs =
      this.numberEnv('NOTIFICATION_REMINDER_LEAD_MINUTES', 60) * 60_000;
    const horizon = new Date(now.getTime() + leadMs);
    const upcoming = await this.bookings.find({
      where: {
        status: In(REMINDER_ELIGIBLE_STATUSES),
        scheduledAt: And(MoreThan(now), LessThanOrEqual(horizon)),
      },
      select: { id: true, customerId: true, providerId: true },
      take: SCAN_CAP,
    });
    let sent = 0;
    for (const booking of upcoming) {
      await this.notifications.send(
        booking.customerId,
        'booking:reminder',
        `reminder:booking:${booking.id}:customer`,
        BOOKING_REMINDER_TEMPLATES.customer,
        booking.id,
      );
      sent += 1;
      if (!booking.providerId) continue;
      await this.notifications.send(
        booking.providerId,
        'booking:reminder',
        `reminder:booking:${booking.id}:provider`,
        BOOKING_REMINDER_TEMPLATES.provider,
        booking.id,
      );
    }
    return sent;
  }

  /** A failed tick is logged by the send path's delivery records; never crash. */
  private async scanSafely(): Promise<void> {
    try {
      await this.scanOnce();
    } catch {
      // The next tick retries; deliveries stay deduplicated.
    }
  }

  private numberEnv(key: string, fallback: number): number {
    const raw = process.env[key]?.trim();
    if (!raw) return fallback;
    const value = Number(raw);
    return Number.isFinite(value) && value > 0 ? value : fallback;
  }
}
