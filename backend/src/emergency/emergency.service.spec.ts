import { ConflictException, NotFoundException } from '@nestjs/common';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { EmergencyService } from './emergency.service';
import {
  EMERGENCY_FALLBACK_GUIDANCE,
  EMERGENCY_POLICY_V1,
} from './emergency-policy';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';

/** The authenticated caller, for the SEC-002 obligation `getStatus` discharges. */
function principalFor(userId: string): AuthorizationPrincipal {
  return { userId, sessionId: 'session-id', roles: ['customer'] };
}

describe('EmergencyService (FN-063)', () => {
  const customerId = '00000000-0000-4000-8000-00000000e001';
  const categoryId = '00000000-0000-4000-8000-00000000e002';
  const bookingId = '00000000-0000-4000-8000-00000000e003';

  const emergencyCategory = {
    id: categoryId,
    isActive: true,
    isEmergency: true,
    name: 'Emergency plumbing',
  };

  let categoryFindOne: jest.Mock;
  let dispatchFindOne: jest.Mock;
  let dispatchSave: jest.Mock;
  let dispatchCreate: jest.Mock;
  let bookingFindOne: jest.Mock;
  let rawRows: Array<Record<string, unknown>>;
  let eventInsert: jest.Mock;
  let advisoryAcquired: boolean;
  let advisoryQueries: unknown[][];
  let outboxEnqueue: jest.Mock;
  let queryRunnerManager: unknown;

  const scanQuery = {
    innerJoin: () => scanQuery,
    where: () => scanQuery,
    andWhere: () => scanQuery,
    orderBy: () => scanQuery,
    addOrderBy: () => scanQuery,
    take: () => scanQuery,
    select: () => scanQuery,
    addSelect: () => scanQuery,
    getRawMany: () => Promise.resolve(rawRows),
    getCount: () => Promise.resolve(rawRows.length),
  };

  // BUG-009: `closeTerminalDispatches` runs a single idempotent UPDATE, so it is
  // the same query builder with an `update`/`execute` tail.
  const closeQuery = {
    update: () => closeQuery,
    set: () => closeQuery,
    where: () => closeQuery,
    andWhere: () => closeQuery,
    execute: () => Promise.resolve({ affected: 0 }),
  };

  const buildService = () => {
    const dispatchRepository = {
      findOneBy: dispatchFindOne,
      save: dispatchSave,
      create: dispatchCreate,
      // BUG-009: the terminal-close sweep takes no alias; the escalation scan
      // does. Two builders, one method, distinguished by the alias - which is
      // how TypeORM itself tells them apart.
      createQueryBuilder: (alias?: string) =>
        alias === undefined ? closeQuery : scanQuery,
    };
    // BUG-015: `recordWave` appends to `waveHistory` under a row lock, inside a
    // transaction, so the manager's repository is a distinct object from the
    // data source's.
    const dispatchManagerRepository = {
      createQueryBuilder: (alias?: string) =>
        alias === undefined ? closeQuery : scanQuery,
      findOne: jest.fn(() =>
        Promise.resolve({
          bookingId,
          currentWave: 0,
          lastEscalatedAt: null,
          waveHistory: [],
        }),
      ),
      save: jest.fn((value: unknown) => Promise.resolve(value)),
    };
    queryRunnerManager = {
      getRepository: (entity: abstract new (...args: never[]) => unknown) =>
        (entity as { name?: string }).name === 'EmergencyDispatch'
          ? dispatchManagerRepository
          : { findOneBy: dispatchFindOne },
    };
    const repos: Record<string, Record<string, unknown>> = {
      ServiceCategoryEntity: { findOneBy: categoryFindOne },
      EmergencyDispatch: dispatchRepository,
      BookingEvent: { insert: eventInsert, create: (v: unknown) => v },
      Booking: { findOneBy: bookingFindOne },
    };
    const dataSource = {
      getRepository: (entity: abstract new (...args: never[]) => unknown) =>
        repos[(entity as { name?: string }).name ?? ''] ?? {},
      manager: queryRunnerManager,
      // FN-082: every outbox enqueue runs inside a caller's transaction, and
      // `recordWave` takes its row lock in one.
      transaction: (cb: (m: unknown) => unknown) =>
        Promise.resolve(cb(queryRunnerManager)),
      createQueryRunner: () => ({
        connect: () => Promise.resolve(),
        release: () => Promise.resolve(),
        query: (sql: string, params?: unknown[]) => {
          advisoryQueries.push([sql, params]);
          if (sql.includes('pg_try_advisory_lock')) {
            return Promise.resolve([{ acquired: advisoryAcquired }]);
          }
          return Promise.resolve([{ pg_advisory_unlock: true }]);
        },
        manager: queryRunnerManager,
      }),
    };
    return new EmergencyService(
      dataSource as never,
      { create: bookingsCreate } as never,
      {
        findEligibleProviders: matchingFind,
        countEligibleProviders: matchingCount,
      } as never,
      { enqueue: outboxEnqueue } as never,
      { send: notificationSend } as never,
      { recordEmergencyFrequencySignal: trustRecord } as never,
    );
  };

  let bookingsCreate: jest.Mock;
  let matchingFind: jest.Mock;
  let matchingCount: jest.Mock;
  let notificationSend: jest.Mock;
  let trustRecord: jest.Mock;

  const baseDto = {
    serviceCategoryId: categoryId,
    description: 'Water everywhere',
    locationLat: 23.02,
    locationLng: 72.57,
  };

  /** The count `create()` reports, which is what the fan-out will find. */
  const supply = (n: number): jest.Mock => jest.fn(() => Promise.resolve(n));

  beforeEach(() => {
    jest.clearAllMocks();
    categoryFindOne = jest.fn().mockResolvedValue(emergencyCategory);
    dispatchFindOne = jest.fn().mockResolvedValue(null);
    dispatchCreate = jest.fn((value: unknown) => value);
    dispatchSave = jest.fn((value: unknown) => Promise.resolve(value));
    bookingFindOne = jest.fn(() =>
      Promise.resolve({
        id: bookingId,
        customerId,
        providerId: null,
        serviceCategoryId: categoryId,
        locationLat: baseDto.locationLat,
        locationLng: baseDto.locationLng,
        status: BookingStatus.REQUESTED,
        version: 1,
      }),
    );
    eventInsert = jest.fn(() => Promise.resolve());
    rawRows = [];
    advisoryAcquired = true;
    advisoryQueries = [];
    outboxEnqueue = jest.fn(() => Promise.resolve(true));
    bookingsCreate = jest.fn(() => {
      const booking = new Booking();
      booking.id = bookingId;
      booking.customerId = customerId;
      booking.locationLat = baseDto.locationLat;
      booking.locationLng = baseDto.locationLng;
      booking.serviceCategoryId = categoryId;
      booking.status = BookingStatus.REQUESTED;
      booking.version = 1;
      // BUG-014: `create()` reports supply, so the emergency path can answer
      // "is there anyone" without running matching a second time.
      return Promise.resolve({
        booking,
        eligibleProviderCount: 2,
        noProviderAvailable: false,
      });
    });
    matchingFind = jest.fn(() =>
      Promise.resolve([
        { providerId: 'p1', distanceKm: 2 },
        { providerId: 'p2', distanceKm: 4 },
      ]),
    );
    matchingCount = supply(2);
    notificationSend = jest.fn(() => Promise.resolve());
    trustRecord = jest.fn(() => Promise.resolve(null));
  });

  it('pins the approved policy constants so silent drift fails this suite', () => {
    expect(EMERGENCY_POLICY_V1.fanOutCap).toBe(50);
    expect(EMERGENCY_POLICY_V1.maxWave).toBe(3);
    expect(EMERGENCY_POLICY_V1.wave2AfterMinutes).toBe(3);
    expect(EMERGENCY_POLICY_V1.wave3AfterMinutes).toBe(8);
    expect(EMERGENCY_POLICY_V1.radiusMultiplierWave2).toBe(2);
    expect(EMERGENCY_POLICY_V1.dailyCustomerCap).toBe(3);
    expect(EMERGENCY_POLICY_V1.cooldownMinutes).toBe(30);
    expect(EMERGENCY_FALLBACK_GUIDANCE).toContain('local emergency services');
  });

  it('rejects categories that are not active emergencies', async () => {
    categoryFindOne.mockResolvedValue({
      ...emergencyCategory,
      isEmergency: false,
    });
    await expect(
      buildService().createEmergency(customerId, baseDto as never, 'key-1'),
    ).rejects.toThrow(ConflictException);
    expect(bookingsCreate).not.toHaveBeenCalled();
  });

  // BUG-015: the dispatch row used to be INSERTed after the booking had already
  // committed, with a comment claiming the gap was self-healing. It was not:
  // the scanner queries emergency_dispatches, so a crash in between left a live
  // emergency that nothing would ever escalate.
  it('records the customer on the dispatch row so the unique index can gate it', async () => {
    await buildService().createEmergency(customerId, baseDto, 'key-1');
    expect(dispatchCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        bookingId,
        customerId,
        currentWave: 0,
        closedAt: null,
      }),
    );
  });

  // FN-082: the wave is a committed row, not work done inline. A pod recycled
  // between the scan and the fan-out still dispatches.
  it('schedules wave 1 through the outbox rather than sending inline', async () => {
    const result = await buildService().createEmergency(
      customerId,
      baseDto,
      'key-1',
    );

    expect(result.bookingId).toBe(bookingId);
    expect(result.currentWave).toBe(1);
    expect(outboxEnqueue).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        kind: 'emergency.wave',
        dedupeKey: `emergency:${bookingId}:w1`,
        payload: { bookingId, customerId, wave: 1 },
      }),
    );
    // The fan-out itself belongs to the worker, so nothing was sent yet.
    expect(notificationSend).not.toHaveBeenCalled();
    expect(eventInsert).toHaveBeenCalled();
  });

  // BUG-022: the dedupe key is the wave, so a wave is dispatched at most once
  // for the life of the booking however many ticks or replicas observe it.
  it('derives the wave key from the wave, not from the caller', async () => {
    await buildService().createEmergency(customerId, baseDto, 'key-1');
    // `enqueue(manager, message)` - the message is the second argument. The
    // mock's call tuple is untyped, so it is read through a narrow cast rather
    // than left as `any`, which the lint rules rightly reject.
    const calls = outboxEnqueue.mock.calls as ReadonlyArray<
      [unknown, { dedupeKey: string }]
    >;
    expect(calls[0]?.[1].dedupeKey).toBe(`emergency:${bookingId}:w1`);
  });

  // BUG-014: the most common failure mode in a marketplace launch is that
  // nobody is online, and it was the one the system handled worst - the customer
  // saw "everything is fine" for the whole eleven-minute ladder.
  describe('when no provider is available (BUG-014)', () => {
    beforeEach(() => {
      bookingsCreate.mockImplementation(() => {
        const booking = new Booking();
        booking.id = bookingId;
        booking.customerId = customerId;
        booking.serviceCategoryId = categoryId;
        booking.status = BookingStatus.REQUESTED;
        booking.version = 1;
        return Promise.resolve({
          booking,
          eligibleProviderCount: 0,
          noProviderAvailable: true,
        });
      });
    });

    it('reports the fallback immediately instead of after three waves', async () => {
      const result = await buildService().createEmergency(
        customerId,
        baseDto,
        'key-empty',
      );
      expect(result.fallbackRequired).toBe(true);
      expect(result.guidance).toBe(EMERGENCY_FALLBACK_GUIDANCE);
      expect(result.eligibleCount).toBe(0);
    });

    it('jumps to the last wave rather than escalating into an empty search', async () => {
      const result = await buildService().createEmergency(
        customerId,
        baseDto,
        'key-empty',
      );
      expect(result.currentWave).toBe(EMERGENCY_POLICY_V1.maxWave);
      expect(outboxEnqueue).not.toHaveBeenCalled();
    });

    it('marks the fallback on the status endpoint once supply is still zero', async () => {
      matchingCount.mockReturnValue(Promise.resolve(0));
      dispatchFindOne.mockResolvedValue({
        bookingId,
        currentWave: 1,
        lastEscalatedAt: new Date(),
        waveHistory: [],
      });
      const status = await buildService().getStatus(
        bookingId,
        principalFor(customerId),
      );
      expect(status.fallbackRequired).toBe(true);
      expect(status.guidance).toBe(EMERGENCY_FALLBACK_GUIDANCE);
      expect(status.eligibleCount).toBe(0);
    });
  });

  it('enforces the cooldown but waives it when the assigned provider cancelled', async () => {
    rawRows = [
      {
        booking_id: 'older',
        created_at: new Date(Date.now() - 10 * 60_000).toISOString(),
        closed_at: new Date().toISOString(),
        status: BookingStatus.CANCELLED,
        provider_id: null, // customer cancelled: cooldown applies
      },
    ];
    await expect(
      buildService().createEmergency(customerId, baseDto as never, 'key-3'),
    ).rejects.toThrow(ConflictException);

    rawRows = [
      {
        booking_id: 'older',
        created_at: new Date(Date.now() - 10 * 60_000).toISOString(),
        closed_at: new Date().toISOString(),
        status: BookingStatus.CANCELLED,
        provider_id: 'p-walked-away',
      },
    ];
    const result = await buildService().createEmergency(
      customerId,
      baseDto,
      'key-4',
    );
    expect(result.currentWave).toBe(1); // stranded customer re-dispatches
  });

  it('stops at the daily cap of emergencies per customer', async () => {
    rawRows = [1, 2, 3].map((n) => ({
      booking_id: `old-${n}`,
      created_at: new Date(Date.now() - n * 60 * 60_000).toISOString(),
      closed_at: new Date().toISOString(),
      status: BookingStatus.CANCELLED,
      provider_id: null,
    }));
    await expect(
      buildService().createEmergency(customerId, baseDto as never, 'key-5'),
    ).rejects.toThrow(/Daily emergency limit/);
  });

  // BUG-009: the "one active emergency" rule used to be a read-then-write, so
  // two requests with different Idempotency-Key headers both read `recent[]`
  // before either wrote and both proceeded. It is a partial unique index now.
  it('no longer reads to decide whether an emergency is already active', async () => {
    // Old enough to clear the 30-minute cooldown, so the only limit this row
    // could trip is the active-dispatch rule - which the application no longer
    // applies. The database does, via UQ_emergency_dispatches_active_customer.
    rawRows = [
      {
        booking_id: 'older',
        created_at: new Date(Date.now() - 5 * 60 * 60_000).toISOString(),
        closed_at: null, // still open
        status: BookingStatus.REQUESTED,
        provider_id: null,
      },
    ];
    const result = await buildService().createEmergency(
      customerId,
      baseDto,
      'key-concurrent',
    );
    expect(result.bookingId).toBe(bookingId);
  });

  it('schedules a due wave-1 dispatch to wave 2 with a widened radius', async () => {
    const service = buildService();
    rawRows = [
      {
        booking_id: bookingId,
        current_wave: 1,
        last_escalated_at: new Date(Date.now() - 4 * 60_000).toISOString(),
        created_at: new Date(Date.now() - 6 * 60_000).toISOString(),
        location_lat: baseDto.locationLat,
        location_lng: baseDto.locationLng,
        category_id: categoryId,
        customer_id: customerId,
      },
    ];
    await service.scanOnce();
    expect(outboxEnqueue).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        kind: 'emergency.wave',
        dedupeKey: `emergency:${bookingId}:w2`,
        payload: { bookingId, customerId, wave: 2 },
      }),
    );
  });

  it('never escalates before the wave threshold elapses', async () => {
    rawRows = [
      {
        booking_id: bookingId,
        current_wave: 1,
        last_escalated_at: new Date(Date.now() - 60_000).toISOString(),
        created_at: new Date(Date.now() - 90_000).toISOString(),
        location_lat: 0,
        location_lng: 0,
        category_id: categoryId,
        customer_id: customerId,
      },
    ];
    await buildService().scanOnce();
    expect(outboxEnqueue).not.toHaveBeenCalled();
  });

  it('marks the honest fallback state only when unassigned at the last wave', async () => {
    const service = buildService();
    dispatchFindOne.mockResolvedValue({
      bookingId,
      currentWave: EMERGENCY_POLICY_V1.maxWave,
      lastEscalatedAt: new Date(),
      waveHistory: [],
    });
    const status = await service.getStatus(bookingId, principalFor(customerId));
    expect(status.fallbackRequired).toBe(true);
    expect(status.guidance).toBe(EMERGENCY_FALLBACK_GUIDANCE);
  });

  it('hides emergency requests from non-participants', async () => {
    const service = buildService();
    await expect(
      service.getStatus(bookingId, principalFor('stranger')),
    ).rejects.toThrow(NotFoundException);
  });

  it('raises the HIGH trust signal only at the repeat-use threshold', async () => {
    rawRows = [1, 2].map((n) => ({ filler: n })); // count below threshold
    await buildService().createEmergency(customerId, baseDto, 'key-6');
    expect(trustRecord).toHaveBeenCalledWith(customerId, 2);

    rawRows = [1, 2, 3].map((n) => ({ filler: n }));
    trustRecord.mockClear();
    await buildService().createEmergency(customerId, baseDto, 'key-7');
    expect(trustRecord).toHaveBeenCalledWith(customerId, 3);
  });

  describe('runWave', () => {
    beforeEach(() => {
      dispatchFindOne.mockResolvedValue({
        bookingId,
        currentWave: 0,
        lastEscalatedAt: null,
        waveHistory: [],
      });
    });

    it('sends to every eligible provider with a permanent per-wave dedupe key', async () => {
      await buildService().runWave(bookingId, 1);
      expect(matchingFind).toHaveBeenCalledWith(
        baseDto.locationLat,
        baseDto.locationLng,
        categoryId,
        EMERGENCY_POLICY_V1.fanOutCap,
        1,
      );
      expect(notificationSend).toHaveBeenCalledTimes(2);

      // Read the captured call rather than asserting through `toHaveBeenCalledWith`
      // and a nest of asymmetric matchers: the template is a
      // `PushNotificationContent`, and every matcher there is typed `any`, so the
      // nested form would assert nothing about the shape.
      const calls = notificationSend.mock.calls as ReadonlyArray<
        [
          string,
          string,
          string,
          { title: string; body: string },
          string,
          unknown,
        ]
      >;
      const [, kind, dedupeKey, template, , options] = calls[0];
      expect(kind).toBe('provider:EMERGENCY_REQUEST');
      expect(dedupeKey).toBe(`emergency:${bookingId}:w1:p1`);
      // The em dash is in the approved copy (policy 8) and is asserted exactly,
      // because a change to approved wording is a policy decision rather than a
      // refactor.
      expect(template.title).toBe('FixNow — Emergency');
      expect(template.body).toContain('Emergency request near you');
      // Emergency pushes override quiet hours (policy 8).
      expect(options).toEqual({ bypassQuietHours: true });
    });

    it('widens the radius on wave 2', async () => {
      await buildService().runWave(bookingId, 2);
      expect(matchingFind).toHaveBeenCalledWith(
        baseDto.locationLat,
        baseDto.locationLng,
        categoryId,
        EMERGENCY_POLICY_V1.fanOutCap,
        EMERGENCY_POLICY_V1.radiusMultiplierWave2,
      );
    });

    // A booking accepted between scheduling and draining must not be re-fanned
    // out. Harmless to correctness - accept is guarded by the version CAS - but
    // it burns the provider's attention, which is the scarce resource here.
    it('sends nothing once the booking is no longer REQUESTED', async () => {
      bookingFindOne.mockResolvedValue({
        id: bookingId,
        customerId,
        providerId: 'p1',
        serviceCategoryId: categoryId,
        locationLat: baseDto.locationLat,
        locationLng: baseDto.locationLng,
        status: BookingStatus.ASSIGNED,
        version: 2,
      });
      expect(await buildService().runWave(bookingId, 1)).toBe(0);
      expect(notificationSend).not.toHaveBeenCalled();
    });
  });

  // BUG-006: the scan ran on a bare `setInterval` in every replica, so three
  // replicas did three times the work with no leader.
  describe('the escalation scan is single-writer across replicas (BUG-006)', () => {
    it('takes a session-scoped advisory lock for the duration of the scan', async () => {
      await buildService().scanOnce();
      const lockCall = advisoryQueries.find(([sql]) =>
        String(sql).includes('pg_try_advisory_lock'),
      );
      const unlockCall = advisoryQueries.find(([sql]) =>
        String(sql).includes('pg_advisory_unlock'),
      );
      expect(lockCall).toBeDefined();
      expect(unlockCall).toBeDefined();
      // A pinned key: every replica must contend for the same one.
      expect(lockCall?.[1]).toEqual(unlockCall?.[1]);
    });

    it('does no work at all when another replica holds the lock', async () => {
      advisoryAcquired = false;
      rawRows = [
        {
          booking_id: bookingId,
          current_wave: 1,
          last_escalated_at: new Date(Date.now() - 4 * 60_000).toISOString(),
          created_at: new Date(Date.now() - 6 * 60_000).toISOString(),
          location_lat: 0,
          location_lng: 0,
          category_id: categoryId,
          customer_id: customerId,
        },
      ];
      expect(await buildService().scanOnce()).toBe(0);
      expect(outboxEnqueue).not.toHaveBeenCalled();
    });

    it('skips a tick while the previous scan is still running', async () => {
      let releaseScan: (() => void) | undefined;
      const blocked = new Promise<void>((resolve) => {
        releaseScan = resolve;
      });
      const scanOnce = jest.fn(() => blocked);

      const service = buildService();
      (service as unknown as { scanOnce: unknown }).scanOnce = scanOnce;
      const scanSafely = (
        service as unknown as { scanSafely: () => Promise<void> }
      ).scanSafely.bind(service);

      const first = scanSafely();
      // The flag is set synchronously before the first await resolves.
      await scanSafely();
      expect(scanOnce).toHaveBeenCalledTimes(1);

      releaseScan?.();
      await first;

      // Once the first scan finishes, the next tick runs again.
      let releaseSecond: (() => void) | undefined;
      const second = new Promise<void>((resolve) => {
        releaseSecond = resolve;
      });
      (service as unknown as { scanOnce: unknown }).scanOnce = jest.fn(
        () => second,
      );
      const next = scanSafely();
      releaseSecond?.();
      await next;
    });
  });

  // BUG-006: the worst case used to be 2,500 strictly sequential sends on a
  // 30-second timer.
  describe('wave fan-out is bounded', () => {
    beforeEach(() => {
      dispatchFindOne.mockResolvedValue({
        bookingId,
        currentWave: 0,
        lastEscalatedAt: null,
        waveHistory: [],
      });
    });

    it('never exceeds the wave concurrency limit', async () => {
      let inFlight = 0;
      let peak = 0;
      // A send that yields, so anything awaited strictly one at a time would
      // serialise and any real bound would be observable.
      notificationSend.mockImplementation(async () => {
        inFlight += 1;
        peak = Math.max(peak, inFlight);
        await new Promise((resolve) => setTimeout(resolve, 1));
        inFlight -= 1;
        return undefined;
      });
      matchingFind.mockResolvedValue(
        Array.from({ length: 30 }, (_, index) => ({
          providerId: `p${index}`,
          distanceKm: index,
        })),
      );

      await buildService().runWave(bookingId, 1);

      expect(notificationSend).toHaveBeenCalledTimes(30);
      // Concurrent, but bounded.
      expect(peak).toBeGreaterThan(1);
      expect(peak).toBeLessThanOrEqual(10);
    });
  });
});
