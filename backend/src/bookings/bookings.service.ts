import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { createHash, createHmac, timingSafeEqual } from 'crypto';
import { ConfigService } from '@nestjs/config';
import {
  DataSource,
  EntityManager,
  IsNull,
  QueryFailedError,
  In,
} from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type { ProviderAbandonmentReason } from '../../../shared/booking-lifecycle.types';
import {
  BookingItemRequestDto,
  CreateBookingDto,
  CreateBookingLineItemDto,
  UpdateBookingItemsDto,
} from './bookings.dto';
import { BookingEvent } from './domain/booking-event.entity';
import { Booking } from './domain/booking.entity';
import { PaymentOrder } from '../payments/domain/payment-order.entity';
import {
  BookingItemSnapshot,
  computeBookingTotals,
} from './domain/booking-items';
import { MatchingService } from '../matching/matching.service';
import { LocationService } from '../location/location.service';
import { BookingProjectionService } from '../realtime/booking-projection.service';
import { DomainNotificationService } from '../notifications/domain/domain-notification.service';
import { TrustService } from '../trust/trust.service';
import { BookingLineItem } from './domain/booking-line-item.entity';
import { SubServiceEntity } from '../services/sub-service.entity';
import { UserEntity } from '../users/user.entity';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { BookingReview } from '../ratings/domain/review.entity';
import { ReviewModerationStatus } from '../../../shared/ratings.types';
import { ProviderCapacityService } from '../providers/availability/provider-capacity.service';
import { mapBounded } from '../common/run-bounded';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import { assertOwnedResource } from '../common/authorization/resource-ownership';
import { ObservabilityService } from '../observability/observability.service';
import { OutboxService } from '../outbox/outbox.service';

/**
 * How many candidate lookups run at once when listing available work. An
 * implementation bound, not a policy number.
 */
const MATCH_LOOKUP_CONCURRENCY = 10;

/**
 * FN-082 (BUG-014). A REQUESTED booking that nobody ever accepted had no exit.
 *
 * The whole backend had three timers - emergency escalation, booking reminders,
 * location cache warming - and none of them expired a REQUESTED booking. So a
 * request created in a city with no online providers returned 201, entered
 * `REQUESTED`, and stayed there. The client showed "searching for providers"
 * forever, because the client had no way to learn the truth: the response
 * carried no eligible count, and the booking never left the state that implies
 * "a search is running".
 *
 * This is the default failure mode on day one of a city launch, which is exactly
 * when nobody is online yet.
 *
 * Two changes close it, and both are needed:
 *   1. `create()` records the eligible count, so the client can branch on a real
 *      number rather than on a spinner that never resolves.
 *   2. The sweeper expires a booking that has had no provider for the grace
 *      period, with a reason the customer can act on.
 */
export const REQUESTED_EXPIRY_SECONDS = positiveEnv(
  'REQUESTED_BOOKING_EXPIRY_SECONDS',
  300,
);

/** Below this, "nobody nearby" is the answer rather than "we are still looking". */
export const NO_PROVIDER_ELIGIBLE_THRESHOLD = 1;

/**
 * How many providers one request is offered to. A shortlist bound, not a policy
 * number - the escalation ladder widens it, it does not start higher.
 */
export const PROVIDER_FANOUT_CAP = 20;

/**
 * BUG-014. Why a request was ended without anybody taking it.
 *
 * The customer's explanation, so it states the fact and the consequence rather
 * than reporting a failure. Written for someone standing on a doorstep who
 * cannot tell the difference between "we are still looking" and "there is
 * nobody" - and it says nothing was charged, because the fear that a closed
 * request will still be billed is the one that stops someone rebooking.
 *
 * Also the `booking_events.reason` on that transition, so the audit trail
 * explains itself to whoever reads it later.
 */
export const NO_PROVIDER_REASON =
  'No provider was available in this area when the request expired. The request was closed automatically and nothing was charged.';

/**
 * BUG-020. From which states each party may cancel.
 *
 * These were inline literals in `cancelBooking`, and the provider list omitted
 * `IN_PROGRESS` while `VALID_BOOKING_TRANSITIONS` permitted it. The two
 * disagreed, so a provider who started a job could not stop it, and the only
 * remaining route to a terminal state was to falsely mark the work complete.
 *
 * Named and exported because the consistency between these lists and
 * `VALID_BOOKING_TRANSITIONS` is exactly the kind of invariant that silently
 * rots - there is a test asserting they agree.
 */
export const CUSTOMER_CANCELLABLE: readonly BookingStatus[] = [
  BookingStatus.REQUESTED,
  BookingStatus.ASSIGNED,
];

export const PROVIDER_CANCELLABLE: readonly BookingStatus[] = [
  BookingStatus.ASSIGNED,
  BookingStatus.EN_ROUTE,
  // Declared legal by the state machine, and now honoured. A provider who
  // started work they cannot finish needs an honest exit; see
  // `PROVIDER_ABANDONMENT_REASONS` for why a bare reason is not enough.
  BookingStatus.IN_PROGRESS,
];

function positiveEnv(key: string, fallback: number): number {
  const raw = process.env[key]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

export interface BookingHistoryPage {
  bookings: Booking[];
  nextCursor: string | null;
}

/**
 * FN-082. What `create()` actually produced, so the caller can branch on the
 * number of providers rather than on a state that implies a search is running.
 *
 * Before this existed the endpoint returned the bare `Booking`, which is
 * structurally incapable of expressing "there is nobody available" - the client
 * saw `status: REQUESTED` and had no basis for any other reading.
 */
export interface BookingCreationResult {
  booking: Booking;
  /**
   * Providers matching this request when it was created, before fan-out. Zero
   * is a real, common answer on day one in a new city, and it is the single
   * fact a customer needs in order to decide whether to wait, widen, or leave.
   */
  eligibleProviderCount: number;
  /**
   * True when the request is not worth waiting on: nobody was eligible at
   * creation and nobody is expected to become eligible. The client should offer
   * alternatives rather than show an indefinite search.
   */
  noProviderAvailable: boolean;
}

export interface ProviderBookingRequestPage {
  bookings: Array<{ booking: Booking; distanceKm: number }>;
}

/**
 * A booking that is created already assigned to a provider, in one transaction.
 *
 * Used by privileged flows that name the provider up front (BUG-011: the
 * guarantee re-service). Nothing here is derived from a client-supplied amount,
 * and nothing bypasses the state machine.
 */
export interface AssignedBookingInput {
  customerId: string;
  providerId: string;
  serviceCategoryId: string;
  description: string;
  locationLat: number;
  locationLng: number;
  /**
   * The already-resolved, server-priced snapshot carried from the original
   * booking. Deliberately NOT `BookingItemRequestDto[]`: re-running
   * `resolveItemSnapshots` here would re-price the re-service at today's
   * catalogue rates, and would refuse to schedule one at all if an original
   * line had since been deactivated. The customer's remedy is the work they
   * were denied, priced as it was quoted.
   */
  items: BookingItemSnapshot[] | null;
  idempotencyKey: string;
  requestFingerprint: string;
  /** Recorded as the actor on both audit events. */
  actorUserId: string;
  /** Recorded on the ASSIGNMENT event so the audit trail explains itself. */
  reason: string;
  isGuaranteeClaim?: boolean;
  parentBookingId?: string | null;
}

interface HistoryCursor {
  createdAt: string;
  id: string;
}

@Injectable()
export class BookingsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly matchingService: MatchingService,
    // Required, and declared before the optional dependencies. An optional
    // capacity service would silently disable the BUG-008 limit whenever the
    // wiring was wrong, which is the same fail-open shape as the ownership bug
    // this branch closed. A missing provider now fails at boot instead.
    private readonly capacity: ProviderCapacityService,
    private readonly outbox: OutboxService,
    private readonly locationService?: LocationService,
    private readonly bookingProjections?: BookingProjectionService,
    private readonly config?: ConfigService,
    private readonly domainNotifications?: DomainNotificationService,
    private readonly trust?: TrustService,
    // Optional for the same reason as the others: a unit test that builds this
    // service with a partial graph should not have to know about metrics.
    // `ObservabilityModule` is `@Global()`, so in the running application this is
    // always injected.
    @Optional() private readonly observability?: ObservabilityService,
  ) {}

  /**
   * BUG-008: a provider's availability must follow their workload, otherwise a
   * provider who finished their last job stays invisible to matching, or keeps
   * being offered jobs they have no capacity for. Best-effort: capacity is a
   * convenience signal, and failing a completed booking because a status update
   * could not be written would be worse than a stale status.
   */
  private async releaseCapacity(
    manager: EntityManager,
    providerId: string,
  ): Promise<void> {
    try {
      await this.capacity.syncAvailabilityForWorkload(manager, providerId);
    } catch {
      // Swallowed on purpose; see the note above.
    }
  }

  /** FN-062: push is best-effort; a notification failure never fails a booking. */
  private async notifySafely(notify: () => Promise<void>): Promise<void> {
    try {
      await notify();
    } catch {
      // Delivery attempts are recorded by the notification service.
    }
  }

  async create(
    userId: string,
    input: CreateBookingDto,
    idempotencyKey: string,
  ): Promise<BookingCreationResult> {
    const normalizedKey = this.validateIdempotencyKey(idempotencyKey);
    const normalizedInput = this.normalizeCreateInput(input);
    const fingerprint = createHash('sha256')
      .update(JSON.stringify(normalizedInput))
      .digest('hex');

    const existing = await this.dataSource.getRepository(Booking).findOneBy({
      customerId: userId,
      idempotencyKey: normalizedKey,
    });
    if (existing) {
      return this.withCreationResult(
        this.resolveIdempotentReplay(existing, fingerprint),
      );
    }

    try {
      const created = await this.dataSource.transaction(async (manager) => {
        // Prices are resolved inside the transaction from the catalogue, so a
        // booking can never persist an amount chosen by the client.
        const items = normalizedInput.requestedItems?.length
          ? await this.resolveItemSnapshots(
              manager,
              normalizedInput.requestedItems,
              normalizedInput.serviceCategoryId,
            )
          : null;
        const totals = computeBookingTotals(items);

        const saved = await this.insertRequestedBooking(manager, {
          customerId: userId,
          serviceCategoryId: normalizedInput.serviceCategoryId,
          idempotencyKey: normalizedKey,
          requestFingerprint: fingerprint,
          actorUserId: userId,
          description: normalizedInput.description,
          items,
          totalAmountMinor: totals.totalMinor || null,
          estimatedDurationMinutes: totals.estimatedDurationMinutes,
          locationLat: normalizedInput.locationLat,
          locationLng: normalizedInput.locationLng,
          scheduledAt: normalizedInput.scheduledAt
            ? new Date(normalizedInput.scheduledAt)
            : null,
          lineItems: normalizedInput.lineItems,
        });

        // FN-082 (BUG-005). The fan-out used to run here, after the commit, on
        // this request thread: matching, then up to 20 providers each costing
        // three database round-trips plus one external FCM HTTPS call per
        // device. A booking could add six seconds of third-party latency to the
        // HTTP response, and at the 60-req/min/IP limit one IP could generate
        // 1,200 outbound calls a minute against a shared Firebase quota - when
        // it ran out, dispatch degraded for every customer, not just the one
        // flooding.
        //
        // Now the intent is recorded in the same transaction as the booking, and
        // a worker performs it. Durability comes free: a pod recycled before the
        // drain still has the row. So does BUG-014's second half - the
        // expiry-sweeper message is written here too, so a request that nobody
        // accepts has a scheduled exit rather than an indefinite search.
        await this.enqueueDispatchWork(manager, saved);
        return saved;
      });
      return this.withCreationResult(created);
    } catch (error: unknown) {
      if (!this.isUniqueViolation(error)) throw error;
      const concurrent = await this.dataSource
        .getRepository(Booking)
        .findOneByOrFail({
          customerId: userId,
          idempotencyKey: normalizedKey,
        });
      return this.withCreationResult(
        this.resolveIdempotentReplay(concurrent, fingerprint),
      );
    }
  }

  /**
   * FN-082. Records everything that must happen after a new request exists.
   *
   * All three messages share the booking's transaction, so a booking can never
   * exist without the intent to dispatch it - which is the failure BUG-005's
   * `void promise()` fix would have introduced on a pod restart.
   */
  private async enqueueDispatchWork(
    manager: EntityManager,
    booking: Booking,
  ): Promise<void> {
    await this.outbox.enqueue(manager, {
      kind: 'booking.provider-fanout',
      // The offer, not the caller. A retried request and the emergency path
      // addressing the same booking derive the same key, so BUG-022's duplicate
      // push becomes a unique violation instead of a race.
      dedupeKey: `booking:${booking.id}:provider-fanout`,
      payload: { bookingId: booking.id },
    });

    await this.outbox.enqueue(manager, {
      kind: 'booking.project',
      dedupeKey: `booking:${booking.id}:project`,
      payload: { bookingId: booking.id },
    });

    // BUG-014. Not conditional: a request that *is* matched may still go
    // unaccepted, and it is the most common way a customer is left waiting. The
    // handler re-checks eligibility before acting, so an accepted booking is a
    // no-op here.
    await this.outbox.enqueue(manager, {
      kind: 'booking.requested-expiry',
      dedupeKey: `booking:${booking.id}:requested-expiry`,
      payload: { bookingId: booking.id },
      availableAt: new Date(Date.now() + REQUESTED_EXPIRY_SECONDS * 1_000),
    });
  }

  /**
   * BUG-014. The number a client needs in order to stop showing a spinner.
   *
   * Read from the same matching predicate the fan-out uses, so the number
   * reported is the number that was actually offered to - not a separate
   * query that could disagree with it.
   */
  private async withCreationResult(
    booking: Booking,
  ): Promise<BookingCreationResult> {
    if (!this.domainNotifications && !this.bookingProjections) {
      return {
        booking,
        eligibleProviderCount: 0,
        noProviderAvailable: false,
      };
    }
    let eligibleProviderCount = 0;
    try {
      const eligible = await this.matchingService.findEligibleProviders(
        booking.locationLat!,
        booking.locationLng!,
        booking.serviceCategoryId,
        PROVIDER_FANOUT_CAP,
      );
      eligibleProviderCount = eligible.length;
    } catch {
      // A failed count must not fail a booking that is already committed. The
      // fan-out worker will retry, and the sweeper is the backstop.
      eligibleProviderCount = 0;
    }
    const noProviderAvailable =
      eligibleProviderCount < NO_PROVIDER_ELIGIBLE_THRESHOLD;

    // Observability. This is the metric the audit said was uncomputable: today
    // there is no way to ask "what fraction of bookings found nobody", and the
    // failure it represents is silent — the booking is created, the search never
    // starts, and the customer sees a spinner. The counter is the only signal
    // that a launch in a new city is failing.
    this.observability?.observeBookingCreate(
      (Date.now() - booking.createdAt.getTime()) / 1000,
      noProviderAvailable ? 'no_provider' : 'created',
    );

    return {
      booking,
      eligibleProviderCount,
      noProviderAvailable,
    };
  }

  /**
   * BUG-014. Ends a request that no provider can serve.
   *
   * Called by the outbox handler once the grace period has passed and matching
   * still reports no supply. It is a real transition, not a direct `UPDATE`:
   * the version CAS means a provider who accepted in the same window wins and
   * this becomes a no-op rather than a cancellation of live work, and
   * `appendEvent` means the reason is in the audit trail that support and
   * trust-and-safety read.
   *
   * The reason string is the customer's explanation, so it has to say what
   * happened and what they can do. "No provider available" alone reads as a
   * system error; the customer needs to know nobody was nearby, because that is
   * a different situation from the request failing.
   */
  async expireUnmatchedRequest(
    bookingId: string,
    expectedVersion: number,
  ): Promise<Booking | null> {
    let expired: Booking | null = null;
    try {
      expired = await this.transition(
        bookingId,
        null,
        expectedVersion,
        async (booking, manager) => {
          // The CAS in `transitionIn` already rejects a booking that has moved
          // on. This is the belt-and-braces check: a provider accepted, so
          // there is nothing to expire, and saying so is more useful than a
          // version conflict.
          if (booking.status !== BookingStatus.REQUESTED) return;
          this.applyDomainTransition(
            booking,
            BookingStatus.CANCELLED,
            NO_PROVIDER_REASON,
          );
          if (booking.providerId) {
            await this.releaseCapacity(manager, booking.providerId);
          }
        },
        NO_PROVIDER_REASON,
      );
    } catch (error) {
      // A stale version means someone else moved the booking, which is the
      // outcome this method wanted. A genuinely unexpected failure is logged by
      // the outbox worker's release path and retried, so it is not swallowed
      // here - only the expected conflict is.
      if (!(error instanceof ConflictException)) throw error;
      return null;
    }

    await this.locationService?.invalidateBooking(bookingId);
    await this.bookingProjections?.publishUnavailable(expired);
    await this.notifySafely(async () => {
      await this.domainNotifications?.notifyBookingEvent(
        expired,
        'customer',
        BookingStatus.CANCELLED,
      );
      if (expired.providerId) {
        await this.domainNotifications?.notifyBookingEvent(
          expired,
          'provider',
          BookingStatus.CANCELLED,
        );
      }
    });
    return expired;
  }

  /**
   * BUG-010: serialise a price rewrite against payment-order creation.
   *
   * The rewrite and `PaymentsService.createForBooking` both key off one booking
   * row, so that row is the thing to lock. Locking the *payment orders* instead
   * would be the obvious-looking mistake and would not work: in the common case
   * there is no order yet, and `SELECT ... FOR UPDATE` on a predicate that
   * matches nothing locks nothing. A concurrent INSERT then proceeds
   * unimpeded and the race survives the "fix".
   *
   * `FOR UPDATE` on the booking conflicts with the same lock in the payment
   * path, so the two cannot interleave:
   *
   *  - rewrite first → payment blocks, then re-reads the new total and refuses
   *    because the gateway was already asked for the old amount
   *  - payment first → rewrite blocks, then observes the committed order and
   *    refuses with a 409
   *
   * A booking row is contended only by its own customer and its own provider,
   * so the lock is narrow in practice. The version CAS in `transitionIn` is
   * untouched: this adds the ordering the CAS cannot provide, namely that a
   * read which *precedes* the CAS sees the other writer's committed state.
   */
  private async lockBookingForPricing(
    manager: EntityManager,
    bookingId: string,
  ): Promise<void> {
    await manager
      .getRepository(Booking)
      .createQueryBuilder('booking')
      .select('booking.id')
      .where('booking.id = :bookingId', { bookingId })
      .setLock('pessimistic_write')
      .getOne();
  }

  /**
   * BUG-010: has a payment order been created for this booking?
   *
   * Called only after {@link lockBookingForPricing}, so the answer cannot go
   * stale before the write that depends on it.
   */
  private async hasPaymentOrder(
    manager: EntityManager,
    bookingId: string,
  ): Promise<boolean> {
    return manager.getRepository(PaymentOrder).exists({ where: { bookingId } });
  }

  /**
   * The single definition of "a booking comes into existence". Both the
   * customer path (`create`) and the privileged already-assigned path
   * (`createAssignedBooking`) go through here, so there is exactly one INSERT,
   * one default shape, and one REQUESTED audit event.
   */
  private async insertRequestedBooking(
    manager: EntityManager,
    params: {
      customerId: string;
      serviceCategoryId: string;
      idempotencyKey: string;
      requestFingerprint: string;
      actorUserId: string;
      description: string;
      items: BookingItemSnapshot[] | null;
      totalAmountMinor: number | null;
      estimatedDurationMinutes: number | null;
      locationLat: number;
      locationLng: number;
      scheduledAt: Date | null;
      lineItems?: CreateBookingLineItemDto[];
      isGuaranteeClaim?: boolean;
      parentBookingId?: string | null;
    },
  ): Promise<Booking> {
    const bookingRepository = manager.getRepository(Booking);
    const booking = bookingRepository.create({
      customerId: params.customerId,
      providerId: null,
      serviceCategoryId: params.serviceCategoryId,
      idempotencyKey: params.idempotencyKey,
      requestFingerprint: params.requestFingerprint,
      status: BookingStatus.REQUESTED,
      description: params.description,
      items: params.items,
      totalAmountMinor: params.totalAmountMinor,
      estimatedDurationMinutes: params.estimatedDurationMinutes,
      locationLat: params.locationLat,
      locationLng: params.locationLng,
      scheduledAt: params.scheduledAt,
      assignedAt: null,
      enRouteAt: null,
      startedAt: null,
      completedAt: null,
      cancelledAt: null,
      cancellationReason: null,
      deletedAt: null,
      isGuaranteeClaim: params.isGuaranteeClaim ?? false,
      parentBookingId: params.parentBookingId ?? null,
    });
    const saved = await bookingRepository.save(booking);

    if (params.lineItems?.length) {
      const lineItemRepo = manager.getRepository(BookingLineItem);
      const subServiceRepo = manager.getRepository(SubServiceEntity);

      const lineItemsToSave = await Promise.all(
        params.lineItems.map(async (item) => {
          const subService = await subServiceRepo.findOneBy({
            id: item.subServiceId,
          });
          if (!subService)
            throw new NotFoundException(
              `SubService ${item.subServiceId} not found`,
            );
          return lineItemRepo.create({
            bookingId: saved.id,
            subServiceId: item.subServiceId,
            quantity: item.quantity,
            priceMinor: subService.priceMinor ?? 0,
          });
        }),
      );
      await lineItemRepo.save(lineItemsToSave);
      saved.lineItems = lineItemsToSave;
    }

    await this.appendEvent(
      manager,
      saved,
      params.actorUserId,
      null,
      BookingStatus.REQUESTED,
      null,
    );
    return saved;
  }

  /**
   * BUG-011. Creates a booking that is already assigned to a named provider, in
   * ONE transaction, through the state machine.
   *
   * The guarantee re-service used to INSERT straight into ASSIGNED with
   * `bookingsRepository.create(...)`. That single line skipped four things the
   * rest of the codebase treats as non-negotiable:
   *
   *   1. `transitionTo()`, so the state machine never saw the edge;
   *   2. the version CAS, so no concurrency control at all;
   *   3. `appendEvent()`, so the booking had NO audit trail - and the admin
   *      booking detail view reads `booking_events`, so the re-service was
   *      invisible to the people who have to investigate it;
   *   4. the idempotency machinery, so a retried request could create a second
   *      live job and charge the customer twice for the remedy.
   *
   * It also produced a booking with `total_amount_minor` NULL, which
   * `payments.service.ts` treats as unpayable - the customer's remedy could not
   * be charged for. The snapshot from the original booking is carried forward,
   * so the re-service is priced exactly as it was quoted.
   *
   * Matching is deliberately not run: the provider is already known, so there is
   * nobody to fan out to.
   */
  async createAssignedBooking(input: AssignedBookingInput): Promise<Booking> {
    const normalizedKey = this.validateIdempotencyKey(input.idempotencyKey);
    const existing = await this.dataSource.getRepository(Booking).findOneBy({
      customerId: input.customerId,
      idempotencyKey: normalizedKey,
    });
    if (existing) return existing;

    if (input.customerId === input.providerId) {
      throw new BadRequestException(
        'A re-service cannot be assigned to the customer it belongs to',
      );
    }

    const totals = computeBookingTotals(input.items);

    try {
      const booking = await this.dataSource.transaction(async (manager) => {
        const created = await this.insertRequestedBooking(manager, {
          customerId: input.customerId,
          serviceCategoryId: input.serviceCategoryId,
          idempotencyKey: normalizedKey,
          requestFingerprint: input.requestFingerprint,
          actorUserId: input.actorUserId,
          description: input.description,
          items: input.items,
          totalAmountMinor: totals.totalMinor || null,
          estimatedDurationMinutes: totals.estimatedDurationMinutes,
          locationLat: input.locationLat,
          locationLng: input.locationLng,
          scheduledAt: null,
          isGuaranteeClaim: input.isGuaranteeClaim,
          parentBookingId: input.parentBookingId,
        });

        // Same edge, same guards and same CAS as a provider accepting. The
        // version is the one the INSERT just produced, so the compare-and-set
        // below is against a real observed version rather than a guess.
        return this.transitionIn(
          manager,
          created.id,
          input.actorUserId,
          created.version,
          async (candidate, txManager) => {
            if (candidate.status !== BookingStatus.REQUESTED) {
              throw new ConflictException('Booking is no longer assignable');
            }
            await this.capacity.assertCanAccept(txManager, input.providerId);
            candidate.providerId = input.providerId;
            candidate.transitionTo(BookingStatus.ASSIGNED);
            await this.capacity.syncAvailabilityForWorkload(
              txManager,
              input.providerId,
            );
          },
          input.reason,
        );
      });

      await this.bookingProjections?.publishBooking(booking);
      await this.notifySafely(async () => {
        await this.domainNotifications!.notifyBookingEvent(
          booking,
          'customer',
          BookingStatus.ASSIGNED,
        );
        await this.domainNotifications!.notifyBookingEvent(
          booking,
          'provider',
          BookingStatus.ASSIGNED,
        );
      });
      return booking;
    } catch (error: unknown) {
      // Two admins pressing the button at once: the loser replays the winner's
      // booking rather than creating a second live job.
      if (!this.isUniqueViolation(error)) throw error;
      return this.dataSource.getRepository(Booking).findOneByOrFail({
        customerId: input.customerId,
        idempotencyKey: normalizedKey,
      });
    }
  }

  async acceptBooking(
    bookingId: string,
    providerId: string,
    expectedVersion: number,
  ): Promise<Booking> {
    const candidate = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!candidate) throw new NotFoundException('Booking not found');

    // Idempotency. A second tap on "Accept" — or a client that retries a
    // request whose response it never saw — used to fall through to
    // `transition()` and be refused with `Booking version is stale`, because the
    // first accept had already bumped the version the retry was carrying. The
    // caller could not tell that apart from losing a genuine race for the job,
    // so the UI reported a failure for something it had already achieved.
    //
    // Both answers are decided here, before the version check, because by the
    // time `transition()` runs the expected version is stale by construction
    // and the retry no longer has a version it could legitimately present.
    if (candidate.providerId === providerId) {
      // This provider already holds the booking. Returning the current row is
      // the answer to "did my acceptance go through?" — yes — rather than an
      // error. No second assignment event and no second notification: the work
      // already happened, and repeating it would page the provider again for a
      // job they are already on.
      return candidate;
    }
    if (candidate.providerId) {
      // Somebody else got it. Named plainly so the client can say so, instead of
      // the generic "no longer available" that read as a bug during testing.
      // Deliberately does not name them: a 409 that identified the winning
      // provider turns this into an oracle for who is working where.
      throw new ConflictException({
        statusCode: 409,
        message: 'Booking has already been accepted by another specialist',
      });
    }

    // BUG-007: eligibility must not depend on the provider's rank in a
    // distance-ordered shortlist. `isProviderEligible` applies the same
    // predicate with no LIMIT, so a provider is judged on merit rather than on
    // whether they made the top 50.
    const eligible = await this.matchingService.isProviderEligible(
      providerId,
      candidate.locationLat!,
      candidate.locationLng!,
      candidate.serviceCategoryId,
    );
    if (!eligible) {
      throw new ForbiddenException('Provider is not eligible for this booking');
    }
    const booking = await this.transition(
      bookingId,
      providerId,
      expectedVersion,
      async (candidate, manager) => {
        if (candidate.customerId === providerId) {
          throw new ForbiddenException(
            'Customers cannot accept their own booking',
          );
        }
        if (candidate.status !== BookingStatus.REQUESTED) {
          throw new ConflictException('Booking is no longer available');
        }
        // BUG-008: capacity is checked inside the assigning transaction, after
        // the availability row is locked, so two simultaneous accepts cannot
        // both see a count below the limit.
        await this.capacity.assertCanAccept(manager, providerId);
        candidate.providerId = providerId;
        candidate.transitionTo(BookingStatus.ASSIGNED);
        // The provider now has work, so stop offering them more jobs.
        await this.capacity.syncAvailabilityForWorkload(manager, providerId);
      },
    );
    await this.bookingProjections?.publishBooking(booking);
    await this.notifySafely(async () => {
      await this.domainNotifications!.notifyBookingEvent(
        booking,
        'customer',
        BookingStatus.ASSIGNED,
      );
      await this.domainNotifications!.notifyBookingEvent(
        booking,
        'provider',
        BookingStatus.ASSIGNED,
      );
    });
    return booking;
  }

  async updateStatus(
    bookingId: string,
    providerId: string,
    status: BookingStatus,
    expectedVersion: number,
  ): Promise<Booking> {
    if (![BookingStatus.EN_ROUTE, BookingStatus.COMPLETED].includes(status)) {
      throw new BadRequestException('Unsupported provider status command');
    }
    const booking = await this.transition(
      bookingId,
      providerId,
      expectedVersion,
      async (booking, manager) => {
        if (booking.providerId !== providerId) {
          throw new ForbiddenException('You are not assigned to this booking');
        }
        this.applyDomainTransition(booking, status);
        if (status === BookingStatus.COMPLETED) {
          await this.releaseCapacity(manager, providerId);
        }
      },
    );
    if (
      status === BookingStatus.IN_PROGRESS ||
      status === BookingStatus.COMPLETED
    ) {
      await this.locationService?.invalidateBooking(bookingId);
    }
    await this.bookingProjections?.publishBooking(booking);
    await this.notifySafely(async () => {
      await this.domainNotifications!.notifyBookingEvent(
        booking,
        'customer',
        status,
      );
      await this.domainNotifications!.notifyBookingEvent(
        booking,
        'provider',
        status,
      );
    });
    return booking;
  }

  async updateBookingLineItems(
    bookingId: string,
    providerId: string,
    lineItemsInput: CreateBookingLineItemDto[],
    expectedVersion: number,
  ): Promise<Booking> {
    const booking = await this.transition(
      bookingId,
      providerId,
      expectedVersion,
      async (booking, manager) => {
        if (booking.providerId !== providerId) {
          throw new ForbiddenException('You are not assigned to this booking');
        }
        if (
          booking.status === BookingStatus.COMPLETED ||
          booking.status === BookingStatus.CANCELLED
        ) {
          throw new ConflictException(
            'Cannot modify line items for a completed or cancelled booking',
          );
        }

        // BUG-010. This path re-priced the booking while its sibling
        // `updateBookingItems` was guarded, so a payment order created in the
        // window produced a paid order whose amount no longer matched the
        // booking, and its capture failed permanently with
        // `payment.captured.amount_mismatch`.
        //
        // Checking inside the transaction was not enough on its own: the check
        // and the rewrite still had to be atomic with respect to
        // `createForBooking`, which is what the booking-row lock provides.
        await this.lockBookingForPricing(manager, bookingId);
        const alreadyPaid = await this.hasPaymentOrder(manager, bookingId);
        if (alreadyPaid) {
          throw new ConflictException(
            'Line items cannot be changed once payment has started',
          );
        }

        const lineItemRepo = manager.getRepository(BookingLineItem);
        const subServiceRepo = manager.getRepository(SubServiceEntity);

        // Remove existing line items for this booking
        await lineItemRepo.delete({ bookingId: booking.id });

        // Add new line items
        if (lineItemsInput.length > 0) {
          const newLineItems = await Promise.all(
            lineItemsInput.map(async (item) => {
              const subService = await subServiceRepo.findOneBy({
                id: item.subServiceId,
              });
              if (!subService || subService.priceMinor === undefined) {
                throw new BadRequestException(
                  `Invalid sub-service or price not set: ${item.subServiceId}`,
                );
              }
              return lineItemRepo.create({
                bookingId: booking.id,
                subServiceId: item.subServiceId,
                quantity: item.quantity,
                priceMinor: subService.priceMinor ?? 0,
              });
            }),
          );
          await lineItemRepo.save(newLineItems);
          booking.lineItems = newLineItems;
        } else {
          booking.lineItems = [];
        }
      },
    );
    await this.bookingProjections?.publishBooking(booking);
    return booking;
  }

  /**
   * BUG-020. Cancels a booking, and gives a provider an honest way out of a job
   * they have started.
   *
   * The per-party allow-list used to be:
   *
   *   customer: [REQUESTED, ASSIGNED]
   *   provider: [ASSIGNED, EN_ROUTE]
   *
   * So `IN_PROGRESS` was a dead end for a provider. The state machine has always
   * allowed `IN_PROGRESS → CANCELLED`, and `VALID_BOOKING_TRANSITIONS` says so -
   * the two disagreed, and a fifteen-line consistency test would have caught it
   * on day one. The consequence was worse than a bug: a provider who started a
   * job and found it misdescribed, unsafe, or impossible had only two options,
   * finish it anyway (which starts the payment clock and records a completion
   * against them) or leave the customer stranded forever. Rules with no honest
   * exit get routed around, and this one was being routed around by providers
   * falsely marking work complete.
   *
   * The exit now exists, and it is structured. A bare free-text reason is not
   * enough: "the customer is not answering" wants a re-dispatch, while "this is
   * not the job I agreed to" is a dispute. The code is recorded in the
   * cancellation reason alongside the human explanation, so support can tell
   * them apart from the cancellation record rather than guessing from prose.
   *
   * Trust is evaluated on the resulting cancellation exactly as before, so an
   * abandonment is visible to the reliability model rather than invisible.
   */
  async cancelBooking(
    bookingId: string,
    userId: string,
    reason: string,
    expectedVersion: number,
    abandonmentReason?: ProviderAbandonmentReason,
  ): Promise<Booking> {
    const normalizedReason = reason.trim();
    let abandoned = false;

    const booking = await this.transition(
      bookingId,
      userId,
      expectedVersion,
      async (booking, manager) => {
        const isCustomer = booking.customerId === userId;
        const isProvider = booking.providerId === userId;
        if (!isCustomer && !isProvider) {
          throw new ForbiddenException(
            'You are not authorized to cancel this booking',
          );
        }
        const allowed = isCustomer
          ? CUSTOMER_CANCELLABLE
          : PROVIDER_CANCELLABLE;
        if (!allowed.includes(booking.status)) {
          throw new ConflictException(
            'Booking cannot be cancelled in its current state',
          );
        }
        if (
          isProvider &&
          booking.status === BookingStatus.IN_PROGRESS &&
          !abandonmentReason
        ) {
          throw new BadRequestException(
            'Abandoning a job you have started requires a reason code. ' +
              'Mark it complete only if the work was actually done.',
          );
        }
        abandoned = isProvider && booking.status === BookingStatus.IN_PROGRESS;

        this.applyDomainTransition(
          booking,
          BookingStatus.CANCELLED,
          abandonmentReason
            ? `${abandonmentReason}: ${normalizedReason}`
            : normalizedReason,
        );
        // A cancellation frees a slot, so the provider may be available again.
        if (booking.providerId) {
          await this.releaseCapacity(manager, booking.providerId);
        }
      },
      abandonmentReason
        ? `${abandonmentReason}: ${normalizedReason}`
        : normalizedReason,
    );
    await this.locationService?.invalidateBooking(bookingId);
    await this.bookingProjections?.publishUnavailable(booking);
    await this.notifySafely(async () => {
      await this.domainNotifications?.notifyBookingEvent(
        booking,
        'customer',
        BookingStatus.CANCELLED,
      );
      if (booking.providerId) {
        await this.domainNotifications?.notifyBookingEvent(
          booking,
          'provider',
          BookingStatus.CANCELLED,
        );
      }
    });

    if (abandoned) {
      // An abandoned job is the platform's problem, not the customer's: a
      // provider did not do the work, so the customer is owed a re-dispatch or a
      // refund, and the reason code tells the client which copy to show. A
      // customer cancellation is a different event and keeps its existing trust
      // meaning.
      //
      // Deliberately NOT re-dispatched here. The booking is CANCELLED, and
      // terminal is terminal - re-listing it would put a job in front of
      // providers that no provider can accept, which is the same
      // never-resolving-search failure BUG-014 exists to remove. The remedy is a
      // new booking the customer makes, which keeps the original record, its
      // audit trail and its conversation intact.
      await this.notifySafely(async () => {
        await this.trust?.evaluateProviderAbandonment(
          booking.providerId!,
          abandonmentReason!,
        );
      });
    } else {
      // FN-060: trust signal recording is best-effort, like notifications.
      await this.notifySafely(async () => {
        await this.trust?.evaluateCustomerCancellationSignal(
          booking.customerId,
        );
      });
      const assignedProviderId = booking.providerId;
      if (assignedProviderId) {
        await this.notifySafely(async () => {
          await this.trust?.evaluateCancellationSignal(assignedProviderId);
        });
      }
    }
    return booking;
  }

  async rescheduleBooking(
    bookingId: string,
    userId: string,
    newScheduledAt: string,
    expectedVersion: number,
    reason?: string,
  ): Promise<Booking> {
    const scheduledDate = new Date(newScheduledAt);
    if (
      isNaN(scheduledDate.getTime()) ||
      scheduledDate.getTime() <= Date.now()
    ) {
      throw new BadRequestException('Rescheduled time must be in the future');
    }
    const booking = await this.transition(
      bookingId,
      userId,
      expectedVersion,
      (candidate) => {
        const isCustomer = candidate.customerId === userId;
        const isProvider = candidate.providerId === userId;
        if (!isCustomer && !isProvider) {
          throw new ForbiddenException(
            'You are not authorized to reschedule this booking',
          );
        }
        const allowed = [BookingStatus.REQUESTED, BookingStatus.ASSIGNED];
        if (!allowed.includes(candidate.status)) {
          throw new ConflictException(
            'Only requested or assigned bookings can be rescheduled',
          );
        }
        candidate.scheduledAt = scheduledDate;
      },
      reason ?? 'Rescheduled booking',
    );
    if (this.domainNotifications) {
      await this.notifySafely(async () => {
        await this.domainNotifications!.notifyBookingEvent(
          booking,
          'customer',
          booking.status,
        );
        if (booking.providerId) {
          await this.domainNotifications!.notifyBookingEvent(
            booking,
            'provider',
            booking.status,
          );
        }
      });
    }
    return booking;
  }

  /**
   * Replaces the booking's itemized lines after the assigned provider finds
   * more (or less) work on site.
   *
   * SECURITY (SEC-001): the provider selects catalogue entries and quantities
   * only. Every price is re-resolved from `sub_services` inside the same
   * transaction, so a provider cannot set a price — including a price of 0,
   * which previously made the booking permanently unpayable.
   *
   * A price change is recorded as a booking event with the provider's reason,
   * so the customer always has an auditable record of what changed and why.
   */
  async updateBookingItems(
    bookingId: string,
    providerId: string,
    input: UpdateBookingItemsDto,
  ): Promise<Booking> {
    const booking = await this.transition(
      bookingId,
      providerId,
      input.expectedVersion,
      async (candidate, manager) => {
        if (candidate.providerId !== providerId) {
          throw new ForbiddenException('You are not assigned to this booking');
        }
        const allowed: BookingStatus[] = [
          BookingStatus.ASSIGNED,
          BookingStatus.EN_ROUTE,
          BookingStatus.IN_PROGRESS,
        ];
        if (!allowed.includes(candidate.status)) {
          throw new ConflictException(
            'Services can only be adjusted while the job is active',
          );
        }
        // BUG-010. Guarded inside the transaction that performs the write,
        // and atomic against concurrent order creation because both paths
        // serialise on the booking row first.
        await this.lockBookingForPricing(manager, bookingId);
        const paid = await this.hasPaymentOrder(manager, bookingId);
        if (paid) {
          throw new ConflictException(
            'A payment has already been initiated for this booking',
          );
        }
        const items = await this.resolveItemSnapshots(
          manager,
          input.items,
          candidate.serviceCategoryId,
        );
        const totals = computeBookingTotals(items);
        candidate.items = items;
        candidate.totalAmountMinor = totals.totalMinor;
        candidate.estimatedDurationMinutes = totals.estimatedDurationMinutes;
      },
      input.reason?.trim()
        ? `Provider adjusted on-site services: ${input.reason.trim()}`
        : 'Provider adjusted on-site services',
    );
    await this.bookingProjections?.publishBooking(booking);
    await this.notifySafely(() =>
      this.domainNotifications!.notifyBookingEvent(
        booking,
        'customer',
        booking.status,
      ),
    );
    return booking;
  }

  /**
   * @param principal the authenticated caller. The SEC-002 ownership
   *   obligation for `POST /bookings/:id/service-start-otp` is discharged here
   *   rather than in the controller: this method returns only the one-time
   *   code, so the booking's `customerId` is never handed back to compare.
   */
  async getServiceStartOtp(
    bookingId: string,
    principal: AuthorizationPrincipal,
  ): Promise<{ otp: string }> {
    const customerId = principal.userId;
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== customerId)
      throw new ForbiddenException(
        'Only the customer can view this service OTP',
      );
    assertOwnedResource(principal, booking.customerId, 'booking.customerId');
    if (booking.status !== BookingStatus.EN_ROUTE)
      throw new ConflictException(
        'The service OTP is available after the provider is en route',
      );
    return { otp: this.serviceStartOtp(booking) };
  }

  async verifyOtpAndStartService(
    bookingId: string,
    providerId: string,
    otp: string,
    expectedVersion: number,
  ): Promise<Booking> {
    const booking = await this.transition(
      bookingId,
      providerId,
      expectedVersion,
      (candidate) => {
        if (candidate.providerId !== providerId)
          throw new ForbiddenException('You are not assigned to this booking');
        if (candidate.status !== BookingStatus.EN_ROUTE)
          throw new ConflictException(
            'Service can start only after the provider is en route',
          );
        const expected = Buffer.from(this.serviceStartOtp(candidate));
        const actual = Buffer.from(otp);
        if (
          expected.length !== actual.length ||
          !timingSafeEqual(expected, actual)
        )
          throw new ForbiddenException('The service start OTP is incorrect');
        candidate.transitionTo(BookingStatus.IN_PROGRESS);
      },
    );
    await this.locationService?.invalidateBooking(bookingId);
    await this.bookingProjections?.publishBooking(booking);
    await this.notifySafely(async () => {
      await this.domainNotifications!.notifyBookingEvent(
        booking,
        'customer',
        BookingStatus.IN_PROGRESS,
      );
      await this.domainNotifications!.notifyBookingEvent(
        booking,
        'provider',
        BookingStatus.IN_PROGRESS,
      );
    });
    return booking;
  }

  async getBookingHistory(
    userId: string,
    limit = 20,
    cursor?: string,
  ): Promise<BookingHistoryPage> {
    const boundedLimit = Math.min(Math.max(Math.trunc(limit), 1), 100);
    const decodedCursor = cursor ? this.decodeCursor(cursor) : null;
    const query = this.dataSource
      .getRepository(Booking)
      .createQueryBuilder('booking')
      .where('(booking.customerId = :userId OR booking.providerId = :userId)', {
        userId,
      })
      .orderBy('booking.createdAt', 'DESC')
      .addOrderBy('booking.id', 'DESC')
      .take(boundedLimit + 1);

    if (decodedCursor) {
      query.andWhere(
        '(booking.createdAt < :cursorDate OR (booking.createdAt = :cursorDate AND booking.id < :cursorId))',
        {
          cursorDate: decodedCursor.createdAt,
          cursorId: decodedCursor.id,
        },
      );
    }

    const rows = await query.getMany();
    const hasMore = rows.length > boundedLimit;
    // `take(limit + 1)` over-fetches by one purely to detect `hasMore`. That
    // extra row must not be returned: the customer asked for `limit` bookings.
    // The admin list services slice here; this one did not, so every page of
    // booking history carried one booking too many.
    const page = rows
      .slice(0, boundedLimit)
      .map((booking) => this.redactDestinationFor(booking, userId));
    await this.populatePhones(page);
    const last = page.at(-1);
    return {
      bookings: page,
      nextCursor:
        hasMore && last
          ? this.encodeCursor({
              createdAt: last.createdAt.toISOString(),
              id: last.id,
            })
          : null,
    };
  }

  /// Single-booking read for a participant (customer or assigned provider).
  /// The tracking screen and booking detail routes resolve snapshots here.
  async getBookingForUser(bookingId: string, userId: string): Promise<Booking> {
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== userId && booking.providerId !== userId) {
      throw new ForbiddenException('Booking participants only');
    }
    return this.redactDestinationFor(booking, userId);
  }

  /// Providers do not receive the customer's exact destination until the job
  /// is theirs and active — matching-stage requests and terminal history stay
  /// coordinate-free, while ASSIGNED/EN_ROUTE/IN_PROGRESS jobs must carry the
  /// destination or navigation and live tracking cannot work.
  private redactDestinationFor(booking: Booking, userId: string): Booking {
    const destinationAllowed: readonly string[] = [
      BookingStatus.ASSIGNED,
      BookingStatus.EN_ROUTE,
      BookingStatus.IN_PROGRESS,
    ];
    if (
      booking.providerId === userId &&
      booking.customerId !== userId &&
      !destinationAllowed.includes(booking.status)
    ) {
      return Object.assign(new Booking(), booking, {
        locationLat: null,
        locationLng: null,
      });
    }
    return booking;
  }

  async getAvailableRequests(
    providerId: string,
    limit = 20,
  ): Promise<ProviderBookingRequestPage> {
    const boundedLimit = Math.min(Math.max(Math.trunc(limit), 1), 50);
    const candidates = await this.dataSource.getRepository(Booking).find({
      where: { status: BookingStatus.REQUESTED, deletedAt: IsNull() },
      order: { createdAt: 'DESC', id: 'DESC' },
      take: Math.min(boundedLimit * 4, 200),
    });
    const bookings: Array<{ booking: Booking; distanceKm: number }> = [];

    // BUG-004: this used to call findEligibleProviders once per candidate and
    // search the top-50 result for the asking provider - up to 200 sequential
    // haversine queries, and a provider who was eligible but not in the nearest
    // 50 was silently dropped from their own available list.
    //
    // One scoped query per candidate, run under a bounded pool. Still a query
    // per candidate; batching them into a single VALUES join would be the next
    // step, and is noted rather than silently left implied.
    //
    // The pool preserves input order, and this list is presented newest-first.
    const matched = await mapBounded(
      candidates.map((booking) => async () => {
        const distanceKm = await this.matchingService.findProviderDistance(
          providerId,
          Number(booking.locationLat),
          Number(booking.locationLng),
          booking.serviceCategoryId,
        );
        return { booking, distanceKm };
      }),
      MATCH_LOOKUP_CONCURRENCY,
    );

    for (const entry of matched) {
      if (!entry || entry.distanceKm === null) continue;
      bookings.push({ booking: entry.booking, distanceKm: entry.distanceKm });
      if (bookings.length === boundedLimit) break;
    }

    await this.populatePhones(bookings.map((b) => b.booking));
    return { bookings };
  }

  async cancelBookingAsAdmin(
    bookingId: string,
    actorUserId: string,
    reason: string,
    expectedVersion: number,
  ): Promise<Booking> {
    const normalizedReason = reason.trim();
    const booking = await this.transition(
      bookingId,
      actorUserId,
      expectedVersion,
      (candidate) => {
        if (
          [BookingStatus.COMPLETED, BookingStatus.CANCELLED].includes(
            candidate.status,
          )
        ) {
          throw new ConflictException(
            'Completed or cancelled bookings cannot be changed',
          );
        }
        this.applyDomainTransition(
          candidate,
          BookingStatus.CANCELLED,
          normalizedReason,
        );
      },
      normalizedReason,
    );
    await this.locationService?.invalidateBooking(bookingId);
    await this.bookingProjections?.publishUnavailable(booking);
    return booking;
  }

  private async transition(
    bookingId: string,
    actorUserId: string | null,
    expectedVersion: number,
    mutate: (booking: Booking, manager: EntityManager) => void | Promise<void>,
    reason: string | null = null,
  ): Promise<Booking> {
    if (!Number.isInteger(expectedVersion) || expectedVersion < 1) {
      throw new BadRequestException(
        'Expected version must be a positive integer',
      );
    }
    return this.dataSource.transaction((manager) =>
      this.transitionIn(
        manager,
        bookingId,
        actorUserId,
        expectedVersion,
        mutate,
        reason,
      ),
    );
  }

  /**
   * The state machine write, scoped to a caller's transaction so a caller that
   * must make the transition atomic with something else (the INSERT in
   * `createAssignedBooking`) can compose the two without a nested transaction.
   */
  private async transitionIn(
    manager: EntityManager,
    bookingId: string,
    actorUserId: string | null,
    expectedVersion: number,
    mutate: (booking: Booking, manager: EntityManager) => void | Promise<void>,
    reason: string | null = null,
  ): Promise<Booking> {
    if (!Number.isInteger(expectedVersion) || expectedVersion < 1) {
      throw new BadRequestException(
        'Expected version must be a positive integer',
      );
    }
    const repository = manager.getRepository(Booking);
    const booking = await repository.findOneBy({ id: bookingId });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.version !== expectedVersion) {
      throw new ConflictException('Booking version is stale');
    }

    const fromStatus = booking.status;
    await mutate(booking, manager);
    const result = await repository
      .createQueryBuilder()
      .update(Booking)
      .set({
        providerId: booking.providerId,
        status: booking.status,
        scheduledAt: booking.scheduledAt,
        items: booking.items,
        totalAmountMinor: booking.totalAmountMinor,
        estimatedDurationMinutes: booking.estimatedDurationMinutes,
        assignedAt: booking.assignedAt,
        enRouteAt: booking.enRouteAt,
        startedAt: booking.startedAt,
        completedAt: booking.completedAt,
        cancelledAt: booking.cancelledAt,
        cancellationReason: booking.cancellationReason,
        version: () => '"version" + 1',
      })
      .where('id = :id AND version = :expectedVersion', {
        id: bookingId,
        expectedVersion,
      })
      .execute();
    if (result.affected !== 1) {
      throw new ConflictException('Booking was modified concurrently');
    }

    booking.version = expectedVersion + 1;
    await this.appendEvent(
      manager,
      booking,
      actorUserId,
      fromStatus,
      booking.status,
      reason,
    );
    return repository.findOneByOrFail({ id: bookingId });
  }

  private async appendEvent(
    manager: EntityManager,
    booking: Booking,
    actorUserId: string | null,
    fromStatus: BookingStatus | null,
    toStatus: BookingStatus,
    reason: string | null,
  ): Promise<void> {
    const repository = manager.getRepository(BookingEvent);
    await repository.save(
      repository.create({
        bookingId: booking.id,
        actorUserId,
        fromStatus,
        toStatus,
        reason,
        bookingVersion: booking.version,
      }),
    );
  }

  private applyDomainTransition(
    booking: Booking,
    status: BookingStatus,
    reason?: string,
  ): void {
    try {
      booking.transitionTo(status, reason);
    } catch (error: unknown) {
      throw new ConflictException(
        error instanceof Error ? error.message : 'Invalid booking transition',
      );
    }
  }

  private serviceStartOtp(booking: Booking): string {
    const secret = this.config?.get<string>('OTP_SECRET');
    if (!secret) throw new Error('OTP_SECRET is not configured');
    const value = createHmac('sha256', secret)
      .update(
        `service-start:${booking.id}:${booking.enRouteAt?.toISOString() ?? ''}`,
      )
      .digest()
      .readUInt32BE(0);
    return (value % 10000).toString().padStart(4, '0');
  }

  private normalizeCreateInput(input: CreateBookingDto) {
    const description = input.description.trim();
    const scheduledAt = input.scheduledAt
      ? new Date(input.scheduledAt).toISOString()
      : null;
    if (scheduledAt && new Date(scheduledAt).getTime() <= Date.now()) {
      throw new BadRequestException('Scheduled time must be in the future');
    }
    return {
      serviceCategoryId: input.serviceCategoryId,
      description,
      // Fingerprint material: the REQUEST, not the resolved snapshot. If the
      // catalogue price changes between two retries of the same request, the
      // fingerprint must not change, or a legitimate retry would be rejected
      // as a conflicting replay.
      requestedItems:
        input.items?.map((item) => ({
          subServiceId: item.subServiceId,
          quantity: item.quantity,
        })) ?? null,
      locationLat: Number(input.locationLat.toFixed(7)),
      locationLng: Number(input.locationLng.toFixed(7)),
      scheduledAt,
      lineItems: input.lineItems,
    };
  }

  /**
   * SECURITY (SEC-001): turns client-selected catalogue entries into a priced
   * snapshot. `name`, `unitPriceMinor` and `durationMinutes` are read from
   * `sub_services` and are NEVER taken from the request body, so the amount
   * charged cannot be chosen by the customer or the provider.
   *
   * An entry is rejected when it does not exist, is inactive, belongs to a
   * different category than the booking, has no catalogue price, or is not
   * denominated in INR.
   */
  private async resolveItemSnapshots(
    manager: EntityManager,
    requested: BookingItemRequestDto[],
    serviceCategoryId: string,
  ): Promise<BookingItemSnapshot[]> {
    const subServiceRepo = manager.getRepository(SubServiceEntity);
    const ids = [...new Set(requested.map((item) => item.subServiceId))];
    const catalogue = await subServiceRepo.findBy({ id: In(ids) });
    const byId = new Map(catalogue.map((s) => [s.id, s]));

    return requested.map((item, index) => {
      const sub = byId.get(item.subServiceId);
      if (!sub) {
        throw new NotFoundException(
          `Service option ${index + 1} no longer exists`,
        );
      }
      if (!sub.isActive) {
        throw new BadRequestException(
          `Service option ${index + 1} is no longer available`,
        );
      }
      if (sub.categoryId !== serviceCategoryId) {
        throw new BadRequestException(
          `Service option ${index + 1} does not belong to the selected category`,
        );
      }
      if (sub.currency && sub.currency.toUpperCase() !== 'INR') {
        throw new BadRequestException(
          `Service option ${index + 1} is not priced in INR`,
        );
      }
      if (sub.priceMinor === null || sub.priceMinor === undefined) {
        throw new BadRequestException(
          `Service option ${index + 1} is priced on request`,
        );
      }
      return {
        id: sub.id,
        name: sub.name,
        quantity: item.quantity,
        unitPriceMinor: sub.priceMinor,
        ...(typeof sub.estimatedDurationMinutes === 'number'
          ? { durationMinutes: sub.estimatedDurationMinutes }
          : {}),
      };
    });
  }

  private validateIdempotencyKey(value: string): string {
    const key = value?.trim();
    if (!/^[A-Za-z0-9._:-]{8,128}$/.test(key)) {
      throw new BadRequestException(
        'Idempotency-Key must contain 8-128 safe characters',
      );
    }
    return key;
  }

  private resolveIdempotentReplay(
    booking: Booking,
    fingerprint: string,
  ): Booking {
    if (booking.requestFingerprint !== fingerprint) {
      throw new ConflictException(
        'Idempotency key was already used with a different request',
      );
    }
    return booking;
  }

  private isUniqueViolation(error: unknown): boolean {
    if (!(error instanceof QueryFailedError)) return false;
    const driverError = error.driverError as { code?: unknown };
    return driverError.code === '23505';
  }

  private encodeCursor(cursor: HistoryCursor): string {
    return Buffer.from(JSON.stringify(cursor)).toString('base64url');
  }

  private decodeCursor(value: string): HistoryCursor {
    try {
      const parsed = JSON.parse(
        Buffer.from(value, 'base64url').toString('utf8'),
      ) as Partial<HistoryCursor>;
      if (
        typeof parsed.createdAt !== 'string' ||
        !Number.isFinite(Date.parse(parsed.createdAt)) ||
        typeof parsed.id !== 'string' ||
        !/^[0-9a-f-]{36}$/i.test(parsed.id)
      ) {
        throw new Error('Invalid cursor fields');
      }
      return { createdAt: parsed.createdAt, id: parsed.id };
    } catch {
      throw new BadRequestException('Invalid booking history cursor');
    }
  }

  private async populatePhones(bookings: Booking[]): Promise<void> {
    if (bookings.length === 0) return;
    const userIds = new Set<string>();
    const providerIds = new Set<string>();
    bookings.forEach((b) => {
      userIds.add(b.customerId);
      if (b.providerId) {
        userIds.add(b.providerId);
        providerIds.add(b.providerId);
      }
    });
    const users = await this.dataSource.getRepository(UserEntity).find({
      where: { id: In([...userIds]) },
    });
    const phoneMap = new Map(users.map((u) => [u.id, u.phone]));

    const providerProfiles =
      providerIds.size > 0
        ? await this.dataSource.getRepository(ProviderProfileEntity).find({
            where: { userId: In([...providerIds]) },
          })
        : [];
    const profileMap = new Map(
      providerProfiles.map((p) => [p.userId, p.displayName]),
    );

    const jobsCounts =
      providerIds.size > 0
        ? await this.dataSource
            .getRepository(Booking)
            .createQueryBuilder('b')
            .select('b.provider_id', 'providerId')
            .addSelect('COUNT(b.id)', 'count')
            .where('b.provider_id IN (:...providerIds)', {
              providerIds: [...providerIds],
            })
            .andWhere('b.status = :completedStatus', {
              completedStatus: BookingStatus.COMPLETED,
            })
            .groupBy('b.provider_id')
            .getRawMany<{ providerId: string; count: string | number }>()
        : [];
    const jobsMap = new Map(
      jobsCounts.map((j) => [j.providerId, Number(j.count)]),
    );

    // Real published-review aggregate per provider. Previously this stamped
    // providerRating = 4.9 and fell back to 48 completed jobs on every booking
    // in every list, so customers were shown a score nobody had given.
    //
    // Found by the integration suite, which is the first time this query has
    // ever executed. It joined `r.booking`, but `BookingReview` declares no
    // `booking` relation - only a `booking_id` column - so TypeORM threw
    // `Relation with property path booking in entity was not found` and the
    // whole request 500'd. Every unit test mocks the repository, so nothing
    // could see it.
    //
    // The join is expressed against the entity rather than a relation path,
    // which keeps the original `b.status = COMPLETED` filter (only a completed
    // booking may be reviewed) without inventing a relation that does not
    // exist. `provider_id` is denormalised on the review row, so the group-by
    // could also have been done without the join; keeping it means the rating
    // still cannot count a review left against a cancelled booking.
    const ratingCounts =
      providerIds.size > 0
        ? await this.dataSource
            .getRepository(BookingReview)
            .createQueryBuilder('r')
            .innerJoin(Booking, 'b', 'b.id = r.booking_id')
            .select('b.provider_id', 'providerId')
            .addSelect('AVG(r.rating)', 'avgRating')
            .addSelect('COUNT(r.id)', 'reviewCount')
            .where('b.provider_id IN (:...providerIds)', {
              providerIds: [...providerIds],
            })
            .andWhere('b.status = :completedStatus', {
              completedStatus: BookingStatus.COMPLETED,
            })
            .andWhere('r.moderation_status = :published', {
              published: ReviewModerationStatus.PUBLISHED,
            })
            .groupBy('b.provider_id')
            .getRawMany<{
              providerId: string;
              avgRating: string | number;
              reviewCount: string | number;
            }>()
        : [];
    const ratingMap = new Map(
      ratingCounts.map((r) => [
        r.providerId,
        {
          average: Number(r.avgRating),
          count: Number(r.reviewCount),
        },
      ]),
    );

    bookings.forEach((b) => {
      b.customerPhone = phoneMap.get(b.customerId) ?? null;
      if (b.providerId) {
        b.providerPhone = phoneMap.get(b.providerId) ?? null;
        b.providerName = profileMap.get(b.providerId) ?? 'Verified Specialist';
        const rating = ratingMap.get(b.providerId);
        // null means "no reviews yet", which the client renders as such.
        b.providerRating = rating && rating.count > 0 ? rating.average : null;
        b.providerJobsCount = jobsMap.get(b.providerId) ?? 0;
      }
    });
  }
}
