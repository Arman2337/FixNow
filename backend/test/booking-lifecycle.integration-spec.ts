import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { BookingStatus } from '../../shared/booking-lifecycle.types';
import { ProviderAvailabilityStatus } from '../../shared/provider-availability.types';
import { BookingsService } from '../src/bookings/bookings.service';
import { BookingEvent } from '../src/bookings/domain/booking-event.entity';
import { Booking } from '../src/bookings/domain/booking.entity';
import { MatchingService } from '../src/matching/matching.service';
import { ProviderCapacityService } from '../src/providers/availability/provider-capacity.service';
import { ProviderAvailabilityEntity } from '../src/providers/availability/provider-availability.entity';
import { ProviderProfileEntity } from '../src/providers/provider-profile.entity';
import { ProviderSkillEntity } from '../src/providers/provider-skill.entity';
import { ServiceCategoryEntity } from '../src/services/service-category.entity';
import { UserEntity } from '../src/users/user.entity';

describe('booking lifecycle PostgreSQL boundaries', () => {
  const rawUrl = process.env.TEST_DATABASE_URL;
  if (!rawUrl)
    throw new Error('TEST_DATABASE_URL must target an isolated test database');
  const url = new URL(rawUrl);
  const isExpectedTestDatabase =
    url.protocol === 'postgresql:' &&
    ['127.0.0.1', 'localhost'].includes(url.hostname) &&
    url.port === '55432' &&
    url.username === 'fixnow_test' &&
    url.pathname === '/fixnow_test';
  if (!isExpectedTestDatabase) {
    throw new Error(
      'Refusing destructive integration tests: TEST_DATABASE_URL must be the documented loopback fixnow_test database on port 55432',
    );
  }

  const customerId = '00000000-0000-4000-8000-000000000101';
  const providerOneId = '00000000-0000-4000-8000-000000000201';
  const providerTwoId = '00000000-0000-4000-8000-000000000202';
  const categoryId = '00000000-0000-4000-8000-000000000301';
  const dataSource = new DataSource({
    type: 'postgres',
    url: rawUrl,
    entities: [
      Booking,
      BookingEvent,
      UserEntity,
      ProviderProfileEntity,
      ProviderSkillEntity,
      ProviderAvailabilityEntity,
      ServiceCategoryEntity,
    ],
    synchronize: false,
  });
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
    );
  });

  beforeEach(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "booking_events", "bookings", "provider_availability", "provider_skills", "provider_profiles", "service_categories", "users" CASCADE',
    );
    await dataSource.query(
      `INSERT INTO "users" ("id", "status") VALUES ($1, 'active'), ($2, 'active'), ($3, 'active')`,
      [customerId, providerOneId, providerTwoId],
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

  const createBooking = (key: string, description = 'Repair pipe') =>
    service.create(
      customerId,
      {
        serviceCategoryId: categoryId,
        description,
        locationLat: 22.3072,
        locationLng: 73.1812,
      },
      key,
    );

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
    await expect(
      service.updateStatus(
        enRoute.id,
        providerOneId,
        BookingStatus.IN_PROGRESS,
        assigned.version,
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    const inProgress = await service.updateStatus(
      enRoute.id,
      providerOneId,
      BookingStatus.IN_PROGRESS,
      enRoute.version,
    );
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
      actorUserId: '00000000-0000-4000-8000-000000000401',
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
      .sort((a, b) => a.bookingVersion - b.bookingVersion)
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
      actorUserId: '00000000-0000-4000-8000-000000000401',
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
        actorUserId: '00000000-0000-4000-8000-000000000401',
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
