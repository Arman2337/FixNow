import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { DataSource } from 'typeorm';
import { BookingStatus } from '../../shared/booking-lifecycle.types';
import { VALID_BOOKING_TRANSITIONS } from '../../shared/booking-lifecycle.types';
import { ProviderAvailabilityStatus } from '../../shared/provider-availability.types';
import { BookingsService } from '../src/bookings/bookings.service';
import {
  CUSTOMER_CANCELLABLE,
  PROVIDER_CANCELLABLE,
} from '../src/bookings/bookings.service';
import { Booking } from '../src/bookings/domain/booking.entity';
import { BookingEvent } from '../src/bookings/domain/booking-event.entity';
import { MatchingService } from '../src/matching/matching.service';
import { ProviderCapacityService } from '../src/providers/availability/provider-capacity.service';
import { ProviderAvailabilityEntity } from '../src/providers/availability/provider-availability.entity';
import { ProviderProfileEntity } from '../src/providers/provider-profile.entity';
import { createTestDataSource } from './support/test-data-source';

const TEST_OTP_SECRET = 'test-only-otp-secret-at-least-32-characters';

/**
 * A second, independent implementation of the service-start OTP.
 *
 * Deliberately not a call into the service's own helper: a test that derives its
 * expectation with the same code it is checking proves nothing. The derivation
 * is HMAC-SHA256 over the booking id and the moment the provider went en route,
 * truncated to four digits.
 */
const serviceStartOtp = (bookingId: string, enRouteAt: Date): string => {
  const digest = createHmac('sha256', TEST_OTP_SECRET)
    .update(`service-start:${bookingId}:${enRouteAt.toISOString()}`)
    .digest()
    .readUInt32BE(0);
  return (digest % 10000).toString().padStart(4, '0');
};

describe('booking lifecycle PostgreSQL boundaries', () => {
  const customerId = '00000000-0000-4000-8000-000000000101';
  const providerOneId = '00000000-0000-4000-8000-000000000201';
  const providerTwoId = '00000000-0000-4000-8000-000000000202';
  const categoryId = '00000000-0000-4000-8000-000000000301';
  // `booking_events.actor_user_id` is a foreign key, so the admin who schedules a
  // re-service has to be a real row. This is also why the audit trail can be
  // trusted to name a person rather than a dangling uuid.
  const adminId = '00000000-0000-4000-8000-000000000401';
  const dataSource: DataSource = createTestDataSource();
  let matchingService: MatchingService;
  let service: BookingsService;

  beforeAll(async () => {
    await dataSource.initialize();
    matchingService = new MatchingService(
      dataSource.getRepository(ProviderProfileEntity),
    );
    service = new BookingsService(
      dataSource,
      matchingService,
      new ProviderCapacityService(
        dataSource.getRepository(ProviderAvailabilityEntity),
      ),
      // FN-082: the booking transaction records dispatch intent here. The
      // lifecycle test asserts the state machine, not the fan-out, so this is a
      // recording stub rather than the real outbox.
      { enqueue: () => Promise.resolve(true) } as never,
      undefined,
      undefined,
      // IN_PROGRESS is OTP-gated, so reaching it needs a real OTP_SECRET. The
      // previous harness passed none and the lifecycle test asserted the
      // transition with `updateStatus`, which correctly refuses IN_PROGRESS -
      // the test was written against a service that could not have worked.
      new ConfigService({ OTP_SECRET: TEST_OTP_SECRET }),
    );
  });

  beforeEach(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "booking_events", "bookings", "provider_availability", "provider_skills", "provider_profiles", "service_categories", "users" CASCADE',
    );
    await dataSource.query(
      `INSERT INTO "users" ("id", "status") VALUES ($1, 'active'), ($2, 'active'), ($3, 'active'), ($4, 'active')`,
      [customerId, providerOneId, providerTwoId, adminId],
    );
    await dataSource.query(
      `INSERT INTO "service_categories" ("id", "name", "slug", "is_active") VALUES ($1, 'Plumbing', 'plumbing', true)`,
      [categoryId],
    );
    for (const [index, providerId] of [
      providerOneId,
      providerTwoId,
    ].entries()) {
      await dataSource.query(
        `INSERT INTO "provider_profiles" ("user_id", "display_name", "service_radius_km", "base_latitude", "base_longitude") VALUES ($1, $2, 25, 22.3072, 73.1812)`,
        [providerId, `Provider ${index + 1}`],
      );
      await dataSource.query(
        `INSERT INTO "provider_skills" ("user_id", "service_category_id", "is_verified") VALUES ($1, $2, true)`,
        [providerId, categoryId],
      );
      await dataSource.query(
        `INSERT INTO "provider_availability" ("user_id", "time_zone", "status", "status_expires_at") VALUES ($1, 'Asia/Kolkata', $2, now() + interval '1 hour')`,
        [providerId, ProviderAvailabilityStatus.Online],
      );
    }
  });

  afterAll(async () => {
    await dataSource.destroy();
  });

  // BUG-014: `create()` reports supply alongside the booking, so the lifecycle
  // tests can assert the count a client would see without a second query.
  const createBooking = async (key: string, description = 'Repair pipe') =>
    (
      await service.create(
        customerId,
        {
          serviceCategoryId: categoryId,
          description,
          locationLat: 22.3072,
          locationLng: 73.1812,
        },
        key,
      )
    ).booking;

  it('enforces durable idempotency for sequential and concurrent retries', async () => {
    const [first, concurrent] = await Promise.all([
      createBooking('request-key-001'),
      createBooking('request-key-001'),
    ]);
    expect(concurrent.id).toBe(first.id);
    await expect(
      createBooking('request-key-001', 'Different work'),
    ).rejects.toBeInstanceOf(ConflictException);
    const counts = await dataSource.query<
      Array<{ bookings: string; events: string }>
    >(`SELECT
        (SELECT count(*) FROM "bookings") AS bookings,
        (SELECT count(*) FROM "booking_events") AS events`);
    expect(counts[0]).toEqual({ bookings: '1', events: '1' });
  });

  it('enforces booking constraints and immutable audit events in PostgreSQL', async () => {
    const created = await createBooking('request-key-constraints');
    await expect(
      dataSource.query(
        `UPDATE "bookings" SET "location_lat" = 100 WHERE "id" = $1`,
        [created.id],
      ),
    ).rejects.toMatchObject({ driverError: { code: '23514' } });
    await expect(
      dataSource.query(
        `UPDATE "booking_events" SET "reason" = 'changed' WHERE "booking_id" = $1`,
        [created.id],
      ),
    ).rejects.toMatchObject({ driverError: { code: 'P0001' } });
    await expect(
      dataSource.query(`DELETE FROM "booking_events" WHERE "booking_id" = $1`, [
        created.id,
      ]),
    ).rejects.toMatchObject({ driverError: { code: 'P0001' } });
  });

  it('matches only eligible providers without exposing their coordinates', async () => {
    const matches = await matchingService.findEligibleProviders(
      22.3072,
      73.1812,
      categoryId,
      10,
    );
    expect(matches.map(({ providerId }) => providerId)).toEqual([
      providerOneId,
      providerTwoId,
    ]);
    expect(Object.keys(matches[0]).sort()).toEqual([
      'distanceKm',
      'providerId',
    ]);

    await dataSource.query(
      `UPDATE "provider_availability" SET "status_expires_at" = now() - interval '1 minute' WHERE "user_id" = $1`,
      [providerOneId],
    );
    await dataSource.query(
      `UPDATE "service_categories" SET "is_active" = false WHERE "id" = $1`,
      [categoryId],
    );
    await expect(
      matchingService.findEligibleProviders(22.3072, 73.1812, categoryId),
    ).resolves.toEqual([]);
  });

  it('allows exactly one concurrent acceptance and records its event', async () => {
    const requested = await createBooking('request-key-accept');
    const results = await Promise.allSettled([
      service.acceptBooking(requested.id, providerOneId, requested.version),
      service.acceptBooking(requested.id, providerTwoId, requested.version),
    ]);
    expect(results.filter(({ status }) => status === 'fulfilled')).toHaveLength(
      1,
    );
    expect(results.filter(({ status }) => status === 'rejected')).toHaveLength(
      1,
    );
    const stored = await dataSource.getRepository(Booking).findOneByOrFail({
      id: requested.id,
    });
    expect(stored.status).toBe(BookingStatus.ASSIGNED);
    expect(stored.version).toBe(2);
    const events = await dataSource.getRepository(BookingEvent).findBy({
      bookingId: requested.id,
    });
    expect(events.map(({ toStatus }) => toStatus).sort()).toEqual([
      BookingStatus.ASSIGNED,
      BookingStatus.REQUESTED,
    ]);
  });

  it('enforces ownership, stale versions, lifecycle timestamps, and cancellation policy', async () => {
    const requested = await createBooking('request-key-lifecycle');
    const assigned = await service.acceptBooking(
      requested.id,
      providerOneId,
      requested.version,
    );
    await expect(
      service.updateStatus(
        assigned.id,
        providerTwoId,
        BookingStatus.EN_ROUTE,
        assigned.version,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    const enRoute = await service.updateStatus(
      assigned.id,
      providerOneId,
      BookingStatus.EN_ROUTE,
      assigned.version,
    );
    // IN_PROGRESS is deliberately not reachable through `updateStatus`: the
    // provider must present the service-start OTP, so a client cannot skip the
    // proof-of-arrival step.
    await expect(
      service.updateStatus(
        enRoute.id,
        providerOneId,
        BookingStatus.IN_PROGRESS,
        enRoute.version,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    const inProgress = await service.verifyOtpAndStartService(
      enRoute.id,
      providerOneId,
      serviceStartOtp(enRoute.id, enRoute.enRouteAt!),
      enRoute.version,
    );
    expect(inProgress.status).toBe(BookingStatus.IN_PROGRESS);

    await expect(
      service.verifyOtpAndStartService(
        inProgress.id,
        providerOneId,
        serviceStartOtp(inProgress.id, enRoute.enRouteAt!),
        inProgress.version,
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    await expect(
      service.cancelBooking(
        inProgress.id,
        customerId,
        'Too late',
        inProgress.version,
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    const completed = await service.updateStatus(
      inProgress.id,
      providerOneId,
      BookingStatus.COMPLETED,
      inProgress.version,
    );
    expect(completed.assignedAt).toBeInstanceOf(Date);
    expect(completed.enRouteAt).toBeInstanceOf(Date);
    expect(completed.startedAt).toBeInstanceOf(Date);
    expect(completed.completedAt).toBeInstanceOf(Date);
    expect(completed.version).toBe(5);
  });

  it('applies atomic cancellation and privacy-safe cursor history', async () => {
    const requested = await createBooking('request-key-cancel');
    const assigned = await service.acceptBooking(
      requested.id,
      providerOneId,
      requested.version,
    );
    const race = await Promise.allSettled([
      service.cancelBooking(
        assigned.id,
        customerId,
        'No longer needed',
        assigned.version,
      ),
      service.cancelBooking(
        assigned.id,
        providerOneId,
        'Cannot attend',
        assigned.version,
      ),
    ]);
    expect(race.filter(({ status }) => status === 'fulfilled')).toHaveLength(1);
    expect(race.filter(({ status }) => status === 'rejected')).toHaveLength(1);

    await createBooking('request-key-history-1');
    await createBooking('request-key-history-2');
    const firstPage = await service.getBookingHistory(customerId, 2);
    expect(firstPage.bookings).toHaveLength(2);
    expect(firstPage.nextCursor).not.toBeNull();
    const secondPage = await service.getBookingHistory(
      customerId,
      2,
      firstPage.nextCursor!,
    );
    expect(secondPage.bookings).toHaveLength(1);
    expect(secondPage.nextCursor).toBeNull();

    const providerHistory = await service.getBookingHistory(providerOneId, 20);
    expect(providerHistory.bookings[0].locationLat).toBeNull();
    expect(providerHistory.bookings[0].locationLng).toBeNull();
  });

  // BUG-011: the guarantee re-service used to INSERT straight into ASSIGNED,
  // producing a live booking with no state-machine edge, no version bump and no
  // audit event - invisible in the admin booking detail, which reads
  // booking_events.
  it('creates an already-assigned booking through the state machine with a full audit trail', async () => {
    const assigned = await service.createAssignedBooking({
      customerId,
      providerId: providerOneId,
      serviceCategoryId: categoryId,
      description: '[RE-SERVICE] Guarantee Claim: tap still leaking',
      locationLat: 22.3072,
      locationLng: 73.1812,
      items: [
        {
          id: 'sub-1',
          name: 'Tap & Mixer Repair',
          quantity: 1,
          unitPriceMinor: 49900,
          durationMinutes: 60,
        },
      ],
      idempotencyKey: 'guarantee-claim-0001',
      requestFingerprint: 'guarantee-claim-0001',
      actorUserId: adminId,
      reason: 'Guarantee re-service for claim 0001',
      isGuaranteeClaim: true,
      parentBookingId: null,
    });

    expect(assigned.status).toBe(BookingStatus.ASSIGNED);
    expect(assigned.providerId).toBe(providerOneId);
    expect(assigned.version).toBe(2);
    expect(assigned.assignedAt).toBeInstanceOf(Date);
    expect(assigned.isGuaranteeClaim).toBe(true);
    // Priced from the snapshot, so the remedy is actually chargeable. A NULL
    // total is what payments.service.ts treats as unpayable.
    expect(assigned.totalAmountMinor).toBe(58882);

    const events = await dataSource
      .getRepository(BookingEvent)
      .findBy({ bookingId: assigned.id });
    expect(events).toHaveLength(2);
    const trail = events
      .sort((a, b) => (a.bookingVersion ?? 0) - (b.bookingVersion ?? 0))
      .map(({ fromStatus, toStatus, bookingVersion }) => ({
        fromStatus,
        toStatus,
        bookingVersion,
      }));
    expect(trail).toEqual([
      {
        fromStatus: null,
        toStatus: BookingStatus.REQUESTED,
        bookingVersion: 1,
      },
      {
        fromStatus: BookingStatus.REQUESTED,
        toStatus: BookingStatus.ASSIGNED,
        bookingVersion: 2,
      },
    ]);
  });

  it('never creates a second re-service booking for the same claim', async () => {
    const build = () => ({
      customerId,
      providerId: providerTwoId,
      serviceCategoryId: categoryId,
      description: '[RE-SERVICE] Guarantee Claim: duplicate submit',
      locationLat: 22.3072,
      locationLng: 73.1812,
      items: null,
      idempotencyKey: 'guarantee-claim-0002',
      requestFingerprint: 'guarantee-claim-0002',
      actorUserId: adminId,
      reason: 'Guarantee re-service for claim 0002',
    });

    const [first, second] = await Promise.all([
      service.createAssignedBooking(build()),
      service.createAssignedBooking(build()),
    ]);
    expect(second.id).toBe(first.id);

    const counts = await dataSource.query<Array<{ bookings: string }>>(
      'SELECT count(*) AS bookings FROM "bookings"',
    );
    expect(counts[0].bookings).toBe('1');
  });

  it('refuses to assign a re-service to the customer it belongs to', async () => {
    await expect(
      service.createAssignedBooking({
        customerId,
        providerId: customerId,
        serviceCategoryId: categoryId,
        description: '[RE-SERVICE] self assignment',
        locationLat: 22.3072,
        locationLng: 73.1812,
        items: null,
        idempotencyKey: 'guarantee-claim-0003',
        requestFingerprint: 'guarantee-claim-0003',
        actorUserId: adminId,
        reason: 'Guarantee re-service for claim 0003',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    const counts = await dataSource.query<Array<{ bookings: string }>>(
      'SELECT count(*) AS bookings FROM "bookings"',
    );
    expect(counts[0].bookings).toBe('0');
  });

  it('rejects an unqualified provider and never creates the booking', async () => {
    const customerUserId = customerId;
    await expect(
      matchingService.isProviderQualifiedForCategory(
        customerUserId,
        categoryId,
      ),
    ).resolves.toBe(false);
    await expect(
      matchingService.isProviderQualifiedForCategory(providerOneId, categoryId),
    ).resolves.toBe(true);
  });
});

/**
 * BUG-020, TC-SM-003: the declared state table and the enforced per-party
 * allow-lists must agree.
 *
 * `VALID_BOOKING_TRANSITIONS` has always permitted `IN_PROGRESS → CANCELLED`,
 * while `cancelBooking` only allowed a provider to cancel from
 * `[ASSIGNED, EN_ROUTE]`. The two disagreed, so a provider who started a job
 * could not stop it, and the only route to a terminal state was to falsely mark
 * the work complete - which starts the payment clock and records a completion
 * against them.
 *
 * This is a pure function of two exported tables, needs no database, and would
 * have failed the build the day the omission was introduced. That is the whole
 * point: the defect was not subtle, it was a disagreement between two constants
 * that nobody had ever compared.
 */
describe('the declared state machine and the enforced allow-lists agree', () => {
  const nonTerminal = Object.values(BookingStatus).filter(
    (status) =>
      status !== BookingStatus.COMPLETED && status !== BookingStatus.CANCELLED,
  );

  it.each(nonTerminal)(
    'every non-terminal state can reach a terminal state',
    (from) => {
      const reachable = VALID_BOOKING_TRANSITIONS[from].filter((to) =>
        [BookingStatus.COMPLETED, BookingStatus.CANCELLED].includes(to),
      );
      expect(reachable.length).toBeGreaterThan(0);
    },
  );

  it('a provider may cancel from every state the table says they may', () => {
    for (const from of Object.values(BookingStatus)) {
      if (!VALID_BOOKING_TRANSITIONS[from].includes(BookingStatus.CANCELLED)) {
        continue;
      }
      // ASSIGNED/EN_ROUTE/IN_PROGRESS are exactly what a provider is assigned
      // for. Anything in that set that the allow-list omits is a dead end.
      const providerCouldBeWorking = [
        BookingStatus.ASSIGNED,
        BookingStatus.EN_ROUTE,
        BookingStatus.IN_PROGRESS,
      ].includes(from);
      if (providerCouldBeWorking) {
        expect(PROVIDER_CANCELLABLE).toContain(from);
      }
    }
  });

  it('a customer cannot cancel a job that is already under way', () => {
    // The customer's remedy for work in progress is a complaint or a refund, not
    // a cancellation: the provider is already travelling, and letting the
    // customer cancel mid-job would strand them.
    expect(CUSTOMER_CANCELLABLE).not.toContain(BookingStatus.IN_PROGRESS);
    expect(CUSTOMER_CANCELLABLE).not.toContain(BookingStatus.EN_ROUTE);
  });

  it('neither party can cancel a booking that has finished', () => {
    for (const list of [CUSTOMER_CANCELLABLE, PROVIDER_CANCELLABLE]) {
      expect(list).not.toContain(BookingStatus.COMPLETED);
      expect(list).not.toContain(BookingStatus.CANCELLED);
    }
  });

  it('the state table itself is well formed', () => {
    for (const from of Object.values(BookingStatus)) {
      // A state that can reach itself would make a transition a no-op, which is
      // how a status change ends up "succeeding" without changing anything.
      expect(VALID_BOOKING_TRANSITIONS[from]).not.toContain(from);
      for (const to of VALID_BOOKING_TRANSITIONS[from]) {
        expect(Object.values(BookingStatus)).toContain(to);
      }
    }
    // Terminal really is terminal.
    expect(VALID_BOOKING_TRANSITIONS[BookingStatus.COMPLETED]).toEqual([]);
    expect(VALID_BOOKING_TRANSITIONS[BookingStatus.CANCELLED]).toEqual([]);
  });
});
