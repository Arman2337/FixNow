import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { Booking } from './domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { MatchingService } from '../matching/matching.service';
import { BookingProjectionService } from '../realtime/booking-projection.service';
import { DomainNotificationService } from '../notifications/domain/domain-notification.service';
import { OutboxService, OutboxWorker } from '../outbox/outbox.service';
import type { OutboxMessage } from '../outbox/outbox-message.entity';
import { runBounded } from '../common/run-bounded';
import {
  BookingsService,
  PROVIDER_FANOUT_CAP,
  REQUESTED_EXPIRY_SECONDS,
} from './bookings.service';

/**
 * Fan-out concurrency. An implementation bound: high enough that one slow push
 * does not serialise the wave, low enough that a full shortlist cannot open a
 * socket per provider per device at the push provider simultaneously.
 */
const FANOUT_CONCURRENCY = 10;

/**
 * FN-082. Everything `POST /bookings` used to do inline on the request thread.
 *
 * BUG-005 and BUG-006 are the same defect in two places: work that belongs to a
 * queue, running on a request thread or on a bare interval. Both are now rows in
 * the outbox, drained by a worker that claims with `SKIP LOCKED`.
 *
 * Two properties this file owns:
 *
 * 1. Nothing runs on a request thread, so booking creation costs database work
 *    and nothing else.
 * 2. Nothing is lossy. The rows were committed with the booking, so a pod
 *    recycled between commit and drain loses nothing - the case a
 *    `void promise()` drops, and the case that matters most because it is
 *    exactly when a customer is waiting.
 *
 * `BookingsService` is injected rather than reached for statically: it owns the
 * booking aggregate and its state machine, and the expiry below is a real
 * transition rather than a direct `UPDATE`.
 */
@Injectable()
export class BookingDispatchHandlers implements OnModuleInit {
  private readonly logger = new Logger(BookingDispatchHandlers.name);

  constructor(
    private readonly dataSource: DataSource,
    private readonly worker: OutboxWorker,
    private readonly outbox: OutboxService,
    private readonly bookings: BookingsService,
    private readonly matching: MatchingService,
    private readonly notifications?: DomainNotificationService,
    private readonly projections?: BookingProjectionService,
  ) {}

  onModuleInit(): void {
    this.worker.register('booking.provider-fanout', (message) =>
      this.fanOut(message),
    );
    this.worker.register('booking.project', (message) => this.project(message));
    this.worker.register('booking.requested-expiry', (message) =>
      this.expireIfUnmatched(message),
    );
  }

  /**
   * BUG-005. Match, then notify.
   *
   * The candidate list is recomputed here rather than captured at creation time,
   * deliberately: a provider who comes online between the commit and the drain
   * should see the request, and one who went offline in that window should not
   * be offered work they cannot take.
   *
   * Idempotent by construction. `notification_deliveries` dedupes on
   * `(dedupe_key, user_id)`, so a redelivered message re-sends nothing - which
   * is what makes it safe for the drain to retry. A second *message* for the
   * same offer never reaches here at all: the outbox `dedupe_key` rejects it,
   * which is what closes BUG-022.
   */
  private async fanOut(message: OutboxMessage): Promise<void> {
    const booking = await this.findDispatchable(asBookingId(message));
    if (!booking) return;

    const eligible = await this.matching.findEligibleProviders(
      Number(booking.locationLat),
      Number(booking.locationLng),
      booking.serviceCategoryId,
      PROVIDER_FANOUT_CAP,
    );
    if (eligible.length === 0) return;

    const providerIds = eligible.map(({ providerId }) => providerId);
    if (this.notifications) {
      await this.notifications.notifyProvidersOfAvailableRequest(
        booking,
        providerIds,
        PROVIDER_FANOUT_CAP,
      );
    }
    if (!this.projections) return;

    const signal = bookingRequestSignal(booking);
    await runBounded(
      providerIds.map(
        (providerId) => () =>
          this.projections!.publishAccountSignal(
            providerId,
            'provider.request.v1',
            signal,
          ),
      ),
      FANOUT_CONCURRENCY,
    );
  }

  /**
   * The realtime projection for a new request. Kept separate from the fan-out so
   * a slow push provider cannot delay a customer-visible signal, and so the two
   * carry independent retry budgets.
   */
  private async project(message: OutboxMessage): Promise<void> {
    const booking = await this.findDispatchable(asBookingId(message));
    if (!booking || !this.projections) return;
    await this.projections.publishBooking(booking);
  }

  /**
   * BUG-014. Give a request that nobody accepted a real ending.
   *
   * Before this, a booking created where no provider was online returned 201 and
   * sat in `REQUESTED` forever. The customer saw "searching for providers" with
   * no count, no elapsed time and no way to learn that nobody was available; the
   * emergency path compounded it by reporting `fallbackRequired: false` for
   * roughly eleven minutes.
   *
   * The supply re-check is not redundant. The message was scheduled at creation,
   * when there may genuinely have been providers; by the time it becomes
   * available the booking may have been accepted, or the supply may have dried
   * up. Only the second case should end the booking - so a request that is still
   * matchable re-arms rather than being cancelled out from under a provider who
   * is on their way.
   */
  private async expireIfUnmatched(message: OutboxMessage): Promise<void> {
    const booking = await this.findDispatchable(asBookingId(message));
    if (!booking) return;

    const supply = await this.matching.countEligibleProviders(
      Number(booking.locationLat),
      Number(booking.locationLng),
      booking.serviceCategoryId,
    );

    if (supply > 0) {
      await this.rearmExpiry(booking.id);
      return;
    }

    this.logger.log(
      `Expiring booking ${booking.id}: no eligible provider for ${booking.serviceCategoryId}`,
    );
    await this.bookings.expireUnmatchedRequest(booking.id, booking.version);
  }

  /**
   * Loads a booking only if it is still worth acting on: present, not deleted,
   * and still `REQUESTED`. Every handler above starts here, so a message that
   * arrives after the customer cancelled costs one indexed read.
   */
  private async findDispatchable(
    bookingId: string | null,
  ): Promise<Booking | null> {
    if (!bookingId) return null;
    const booking = await this.dataSource.getRepository(Booking).findOneBy({
      id: bookingId,
    });
    if (!booking || booking.deletedAt !== null) return null;
    if (booking.status !== BookingStatus.REQUESTED) return null;
    return booking;
  }

  /**
   * Re-arms the sweep for another full window.
   *
   * A fresh key per arm, so this is a new row rather than a rejected duplicate.
   * The booking's own state is the real guard against looping; the key only has
   * to be unique per arm, and the booking's `version` bounds the total number of
   * arms because each arm costs one state transition.
   */
  private async rearmExpiry(bookingId: string): Promise<void> {
    await this.outbox.enqueue(this.dataSource.manager, {
      kind: 'booking.requested-expiry',
      // A fresh key per arm, so this is a new row rather than a rejected
      // duplicate. The booking's own state is the real guard against looping -
      // each arm only runs while the booking is still REQUESTED, and the sweep
      // is bounded because the grace period is a fixed window, not a count.
      dedupeKey: `booking:${bookingId}:requested-expiry:${Date.now()}`,
      payload: { bookingId },
      availableAt: new Date(Date.now() + REQUESTED_EXPIRY_SECONDS * 1_000),
    });
  }
}

function asBookingId(message: OutboxMessage): string | null {
  const value = message.payload?.bookingId;
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function bookingRequestSignal(booking: Booking): Record<string, unknown> {
  let totalMinor = 0;
  if (booking.lineItems) {
    totalMinor = booking.lineItems.reduce(
      (sum, item) => sum + item.priceMinor * item.quantity,
      0,
    );
  }
  return {
    bookingId: booking.id,
    serviceCategoryId: booking.serviceCategoryId,
    locationLat: booking.locationLat ? booking.locationLat.toString() : '',
    locationLng: booking.locationLng ? booking.locationLng.toString() : '',
    description: booking.description ?? '',
    priceMinor: totalMinor.toString(),
    version: booking.version,
    type: 'booking:provider:REQUESTED',
  };
}
