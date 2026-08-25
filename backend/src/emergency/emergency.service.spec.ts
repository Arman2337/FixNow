import { ConflictException, NotFoundException } from '@nestjs/common';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { EmergencyService } from './emergency.service';
import {
  EMERGENCY_FALLBACK_GUIDANCE,
  EMERGENCY_POLICY_V1,
} from './emergency-policy';

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
  let rawRows: Array<Record<string, unknown>>;
  let eventInsert: jest.Mock;

  const buildService = () => {
    const dispatchQuery = {
      innerJoin: () => dispatchQuery,
      where: () => dispatchQuery,
      andWhere: () => dispatchQuery,
      orderBy: () => dispatchQuery,
      take: () => dispatchQuery,
      select: () => dispatchQuery,
      addSelect: () => dispatchQuery,
      getRawMany: () => Promise.resolve(rawRows),
      getCount: () => Promise.resolve(rawRows.length),
    };
    const repos: Record<string, Record<string, unknown>> = {
      ServiceCategoryEntity: { findOneBy: categoryFindOne },
      EmergencyDispatch: {
        findOneBy: dispatchFindOne,
        save: dispatchSave,
        create: dispatchCreate,
        createQueryBuilder: () => dispatchQuery,
      },
      BookingEvent: { insert: eventInsert, create: (v: unknown) => v },
    };
    const dataSource = {
      getRepository: (entity: abstract new (...args: never[]) => unknown) =>
        repos[(entity as { name?: string }).name ?? ''] ?? {},
    };
    return new EmergencyService(
      dataSource as never,
      { create: bookingsCreate } as never,
      { findEligibleProviders: matchingFind } as never,
      { send: notificationSend } as never,
      { recordEmergencyFrequencySignal: trustRecord } as never,
    );
  };

  let bookingsCreate: jest.Mock;
  let matchingFind: jest.Mock;
  let notificationSend: jest.Mock;
  let trustRecord: jest.Mock;

  const baseDto = {
    serviceCategoryId: categoryId,
    description: 'Water everywhere',
    locationLat: 23.02,
    locationLng: 72.57,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    categoryFindOne = jest.fn().mockResolvedValue(emergencyCategory);
    dispatchFindOne = jest.fn().mockResolvedValue(null);
    dispatchCreate = jest.fn((value: unknown) => value);
    dispatchSave = jest.fn((value: unknown) => Promise.resolve(value));
    eventInsert = jest.fn(() => Promise.resolve());
    rawRows = [];
    bookingsCreate = jest.fn(() => {
      const booking = new Booking();
      booking.id = bookingId;
      booking.customerId = customerId;
      booking.locationLat = baseDto.locationLat;
      booking.locationLng = baseDto.locationLng;
      booking.serviceCategoryId = categoryId;
      booking.status = BookingStatus.REQUESTED;
      booking.version = 1;
      return Promise.resolve(booking);
    });
    matchingFind = jest.fn(() =>
      Promise.resolve([
        { providerId: 'p1', distanceKm: 2 },
        { providerId: 'p2', distanceKm: 4 },
      ]),
    );
    notificationSend = jest.fn(() => Promise.resolve());
    trustRecord = jest.fn(() => Promise.resolve(null));
  });

  it('pins the approved policy constants so silent drift fails this suite', () => {
    expect(EMERGENCY_POLICY_V1.fanOutCap).toBe(50);
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

  it('creates the booking, sidecar row, audit event, and wave-1 fan-out', async () => {
    const result = await buildService().createEmergency(
      customerId,
      baseDto,
      'key-1',
    );

    expect(result.bookingId).toBe(bookingId);
    expect(result.currentWave).toBe(1);
    expect(matchingFind).toHaveBeenCalledWith(
      baseDto.locationLat,
      baseDto.locationLng,
      categoryId,
      EMERGENCY_POLICY_V1.fanOutCap,
      1,
    );
    expect(notificationSend).toHaveBeenCalledTimes(2);
    expect(notificationSend).toHaveBeenCalledWith(
      'p1',
      'provider:EMERGENCY_REQUEST',
      `emergency:${bookingId}:w1:p1`,
      expect.objectContaining({
        body: 'Emergency request near you — open FixNow.',
      }),
      bookingId,
      { bypassQuietHours: true },
    );
    expect(dispatchSave).toHaveBeenCalled();
    expect(eventInsert).toHaveBeenCalled();
  });

  it('blocks a second creation while an emergency is still active', async () => {
    rawRows = [
      {
        booking_id: 'older',
        created_at: new Date(Date.now() - 5 * 60_000).toISOString(),
        status: BookingStatus.REQUESTED,
        provider_id: null,
      },
    ];
    await expect(
      buildService().createEmergency(customerId, baseDto as never, 'key-2'),
    ).rejects.toThrow(ConflictException);
    expect(bookingsCreate).not.toHaveBeenCalled();
  });

  it('enforces the cooldown but waives it when the assigned provider cancelled', async () => {
    rawRows = [
      {
        booking_id: 'older',
        created_at: new Date(Date.now() - 10 * 60_000).toISOString(),
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
      status: BookingStatus.CANCELLED,
      provider_id: null,
    }));
    await expect(
      buildService().createEmergency(customerId, baseDto as never, 'key-5'),
    ).rejects.toThrow(/Daily emergency limit/);
  });

  it('escalates a due wave-1 dispatch to wave 2 with widened radius', async () => {
    const service = buildService();
    const dueReference = new Date(Date.now() - 4 * 60_000); // past the 3-minute mark
    rawRows = [
      {
        booking_id: bookingId,
        current_wave: 1,
        last_escalated_at: dueReference.toISOString(),
        created_at: new Date(Date.now() - 6 * 60_000).toISOString(),
        location_lat: baseDto.locationLat,
        location_lng: baseDto.locationLng,
        category_id: categoryId,
        customer_id: customerId,
        version: 1,
      },
    ];
    // Scanner reads dispatches through its own query; runWave re-reads the row.
    dispatchFindOne.mockResolvedValue({
      bookingId,
      currentWave: 1,
      lastEscalatedAt: dueReference,
      waveHistory: [],
    });
    await service.scanOnce();

    expect(matchingFind).toHaveBeenLastCalledWith(
      baseDto.locationLat,
      baseDto.locationLng,
      categoryId,
      EMERGENCY_POLICY_V1.fanOutCap,
      EMERGENCY_POLICY_V1.radiusMultiplierWave2,
    );
    expect(notificationSend).toHaveBeenCalledWith(
      expect.any(String),
      'provider:EMERGENCY_REQUEST',
      expect.stringContaining(':w2:'),
      expect.anything(),
      bookingId,
      { bypassQuietHours: true },
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
        version: 1,
      },
    ];
    await buildService().scanOnce();
    expect(notificationSend).not.toHaveBeenCalled();
  });

  it('marks the honest fallback state only when unassigned at wave 3', async () => {
    const service = buildService();
    dispatchFindOne.mockResolvedValue({
      bookingId,
      currentWave: 3,
      lastEscalatedAt: new Date(),
      waveHistory: [],
    });
    // getStatus loads the booking through the data source Booking repo.
    (
      service as unknown as {
        dataSource: { getRepository: (e: unknown) => unknown };
      }
    ).dataSource.getRepository = (entity: abstract new () => unknown) =>
      entity === Booking
        ? {
            findOneBy: () =>
              Promise.resolve({
                id: bookingId,
                customerId,
                providerId: null,
                status: BookingStatus.REQUESTED,
                version: 1,
              }),
          }
        : {
            findOneBy: dispatchFindOne,
          };

    const status = await service.getStatus(bookingId, customerId);
    expect(status.fallbackRequired).toBe(true);
    expect(status.guidance).toBe(EMERGENCY_FALLBACK_GUIDANCE);
  });

  it('hides emergency requests from non-participants', async () => {
    const service = buildService();
    (
      service as unknown as {
        dataSource: { getRepository: (e: unknown) => unknown };
      }
    ).dataSource.getRepository = () => ({
      findOneBy: () =>
        Promise.resolve({
          id: bookingId,
          customerId,
          providerId: null,
          status: BookingStatus.REQUESTED,
          version: 1,
        }),
    });
    await expect(service.getStatus(bookingId, 'stranger')).rejects.toThrow(
      NotFoundException,
    );
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
});
