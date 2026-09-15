import { ConflictException, ForbiddenException } from '@nestjs/common';
import type { DataSource, EntityManager, Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type { MatchingService } from '../matching/matching.service';
import { BookingsService } from './bookings.service';
import { BookingEvent } from './domain/booking-event.entity';
import { Booking } from './domain/booking.entity';
import { PaymentOrder } from '../payments/domain/payment-order.entity';

describe('BookingsService', () => {
  let service: BookingsService;
  let bookingRepository: jest.Mocked<Repository<Booking>>;
  let eventRepository: jest.Mocked<Repository<BookingEvent>>;
  let dataSource: jest.Mocked<DataSource>;
  let manager: jest.Mocked<EntityManager>;
  let matchingService: jest.Mocked<MatchingService>;
  let bookingFindOneBy: jest.Mock;
  let bookingFind: jest.Mock;
  let bookingSave: jest.Mock;
  let eventSave: jest.Mock;
  let orderExist: jest.Mock;

  const booking = (overrides: Partial<Booking> = {}): Booking =>
    Object.assign(new Booking(), {
      id: '00000000-0000-4000-8000-000000000101',
      customerId: '00000000-0000-4000-8000-000000000001',
      providerId: null,
      serviceCategoryId: '00000000-0000-4000-8000-000000000010',
      idempotencyKey: 'request-key-123',
      requestFingerprint: '',
      status: BookingStatus.REQUESTED,
      description: 'Repair a leaking pipe',
      locationLat: 22.3,
      locationLng: 73.2,
      scheduledAt: null,
      assignedAt: null,
      enRouteAt: null,
      startedAt: null,
      completedAt: null,
      cancelledAt: null,
      cancellationReason: null,
      deletedAt: null,
      createdAt: new Date('2026-08-12T10:00:00.000Z'),
      updatedAt: new Date('2026-08-12T10:00:00.000Z'),
      version: 1,
      ...overrides,
    });

  beforeEach(() => {
    bookingFindOneBy = jest.fn();
    bookingFind = jest.fn();
    bookingSave = jest.fn();
    eventSave = jest.fn().mockResolvedValue(new BookingEvent());
    bookingRepository = {
      findOneBy: bookingFindOneBy,
      find: bookingFind,
      findOneByOrFail: jest.fn(),
      create: jest.fn((value: Partial<Booking>) => booking(value)),
      save: bookingSave,
      createQueryBuilder: jest.fn(),
    } as unknown as jest.Mocked<Repository<Booking>>;
    eventRepository = {
      create: jest.fn((value: Partial<BookingEvent>) =>
        Object.assign(new BookingEvent(), value),
      ),
      save: eventSave,
    } as unknown as jest.Mocked<Repository<BookingEvent>>;
    manager = {
      getRepository: jest.fn((entity: unknown) =>
        entity === Booking ? bookingRepository : eventRepository,
      ),
    } as unknown as jest.Mocked<EntityManager>;
    orderExist = jest.fn().mockResolvedValue(false);
    const orderRepository = { exists: orderExist };
    dataSource = {
      getRepository: jest.fn((entity: unknown) =>
        entity === PaymentOrder ? orderRepository : bookingRepository,
      ),
      transaction: jest.fn(
        (callback: (transactionManager: EntityManager) => unknown) =>
          Promise.resolve(callback(manager)),
      ),
    } as unknown as jest.Mocked<DataSource>;
    matchingService = {
      findEligibleProviders: jest.fn(),
    } as unknown as jest.Mocked<MatchingService>;
    service = new BookingsService(dataSource, matchingService);
  });

  it('creates a booking and an initial immutable lifecycle event', async () => {
    bookingFindOneBy.mockResolvedValue(null);
    bookingSave.mockImplementation((value: Booking) => {
      value.requestFingerprint ||= 'generated-fingerprint';
      return Promise.resolve(value);
    });

    const result = await service.create(
      '00000000-0000-4000-8000-000000000001',
      {
        serviceCategoryId: '00000000-0000-4000-8000-000000000010',
        description: ' Repair a leaking pipe ',
        locationLat: 22.3,
        locationLng: 73.2,
      },
      'request-key-123',
    );

    expect(result.description).toBe('Repair a leaking pipe');
    expect(eventSave).toHaveBeenCalledTimes(1);
  });

  it('snapshots line items and recomputes totals and duration server-side', async () => {
    bookingFindOneBy.mockResolvedValue(null);
    bookingSave.mockImplementation((value: Booking) =>
      Promise.resolve(value),
    );

    const result = await service.create(
      '00000000-0000-4000-8000-000000000001',
      {
        serviceCategoryId: '00000000-0000-4000-8000-000000000010',
        description: 'Repair a leaking pipe',
        locationLat: 22.3,
        locationLng: 73.2,
        items: [
          {
            id: 'plumb-3',
            name: 'Shower & Water Pipe Leakage',
            quantity: 2,
            unitPriceMinor: 24900,
            durationMinutes: 45,
          },
          {
            id: 'plumb-1',
            name: 'Tap & Mixer Repair',
            quantity: 1,
            unitPriceMinor: 14900,
            durationMinutes: 30,
          },
        ],
      },
      'request-key-123',
    );

    // 2×24900 + 1×14900 = 64700; GST 18% = 11646; duration 2×45 + 30 = 120.
    expect(result.items).toEqual([
      {
        id: 'plumb-3',
        name: 'Shower & Water Pipe Leakage',
        quantity: 2,
        unitPriceMinor: 24900,
        durationMinutes: 45,
      },
      {
        id: 'plumb-1',
        name: 'Tap & Mixer Repair',
        quantity: 1,
        unitPriceMinor: 14900,
        durationMinutes: 30,
      },
    ]);
    expect(result.totalAmountMinor).toBe(76346);
    expect(result.estimatedDurationMinutes).toBe(120);
  });

  it('leaves items and totals empty when no line items are sent', async () => {
    bookingFindOneBy.mockResolvedValue(null);
    bookingSave.mockImplementation((value: Booking) =>
      Promise.resolve(value),
    );

    const result = await service.create(
      '00000000-0000-4000-8000-000000000001',
      {
        serviceCategoryId: '00000000-0000-4000-8000-000000000010',
        description: 'Repair a leaking pipe',
        locationLat: 22.3,
        locationLng: 73.2,
      },
      'request-key-123',
    );

    expect(result.items).toBeNull();
    expect(result.totalAmountMinor).toBeNull();
    expect(result.estimatedDurationMinutes).toBeNull();
  });

  it('returns an existing booking for an identical idempotent replay', async () => {
    bookingFindOneBy.mockResolvedValue(null);
    bookingSave.mockImplementation((value: Booking) => Promise.resolve(value));
    const input = {
      serviceCategoryId: '00000000-0000-4000-8000-000000000010',
      description: 'Repair a leaking pipe',
      locationLat: 22.3,
      locationLng: 73.2,
    };
    const created = await service.create(
      'customer-id',
      input,
      'request-key-123',
    );
    bookingFindOneBy.mockResolvedValue(created);

    await expect(
      service.create('customer-id', input, 'request-key-123'),
    ).resolves.toBe(created);
  });

  it('rejects reuse of an idempotency key with a different payload', async () => {
    bookingFindOneBy.mockResolvedValue(
      booking({ requestFingerprint: 'different-fingerprint' }),
    );
    await expect(
      service.create(
        'customer-id',
        {
          serviceCategoryId: '00000000-0000-4000-8000-000000000010',
          description: 'Different work',
          locationLat: 22.3,
          locationLng: 73.2,
        },
        'request-key-123',
      ),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects acceptance by an ineligible provider', async () => {
    bookingFindOneBy.mockResolvedValue(booking());
    matchingService.findEligibleProviders.mockResolvedValue([]);

    await expect(
      service.acceptBooking(
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000002',
        1,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rejects malformed history cursors', async () => {
    await expect(
      service.getBookingHistory('customer-id', 20, 'not-json'),
    ).rejects.toThrow('Invalid booking history cursor');
  });

  it('returns only requests for which the provider is currently eligible', async () => {
    const first = booking({ id: '00000000-0000-4000-8000-000000000201' });
    const second = booking({ id: '00000000-0000-4000-8000-000000000202' });
    bookingFind.mockResolvedValue([first, second]);
    matchingService.findEligibleProviders
      .mockResolvedValueOnce([{ providerId: 'provider-id', distanceKm: 2.4 }])
      .mockResolvedValueOnce([]);

    await expect(
      service.getAvailableRequests('provider-id', 20),
    ).resolves.toEqual({
      bookings: [{ booking: first, distanceKm: 2.4 }],
    });
  });

  it('prevents an admin intervention from rewriting completed history', async () => {
    bookingFindOneBy.mockResolvedValue(
      booking({ status: BookingStatus.COMPLETED, completedAt: new Date() }),
    );

    await expect(
      service.cancelBookingAsAdmin(
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000099',
        'Operational correction',
        1,
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(eventSave).not.toHaveBeenCalled();
  });

  describe('updateBookingItems', () => {
    const stubTransition = (updated: Booking) => {
      const builder = {
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 1 }),
      };
      (bookingRepository.createQueryBuilder as jest.Mock).mockReturnValue(
        builder,
      );
      (bookingRepository.findOneByOrFail as jest.Mock).mockResolvedValue(
        updated,
      );
      return builder;
    };

    const activeJob = () =>
      booking({
        providerId: 'provider-1',
        status: BookingStatus.IN_PROGRESS,
        version: 2,
      });

    it('replaces items and recomputes totals for the assigned provider', async () => {
      const original = activeJob();
      bookingFindOneBy.mockResolvedValue(original);
      const updated = activeJob();
      updated.version = 3;
      const builder = stubTransition(updated);

      const result = await service.updateBookingItems(
        '00000000-0000-4000-8000-000000000101',
        'provider-1',
        {
          expectedVersion: 2,
          items: [
            {
              id: 'plumb-3',
              name: 'Shower & Water Pipe Leakage',
              quantity: 2,
              unitPriceMinor: 24900,
              durationMinutes: 45,
            },
          ],
        },
      );

      // 2×24900 = 49800 subtotal; GST 8964; duration 90.
      expect(builder.set).toHaveBeenCalledWith(
        expect.objectContaining({
          items: [
            {
              id: 'plumb-3',
              name: 'Shower & Water Pipe Leakage',
              quantity: 2,
              unitPriceMinor: 24900,
              durationMinutes: 45,
            },
          ],
          totalAmountMinor: 58764,
          estimatedDurationMinutes: 90,
        }),
      );
      expect(result).toBe(updated);
      expect(eventSave).toHaveBeenCalledTimes(1);
    });

    it('rejects adjustment by a provider who is not assigned', async () => {
      bookingFindOneBy.mockResolvedValue(activeJob());

      await expect(
        service.updateBookingItems(
          '00000000-0000-4000-8000-000000000101',
          'not-the-provider',
          { expectedVersion: 2, items: [] },
        ),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('rejects adjustment once a payment order exists', async () => {
      orderExist.mockResolvedValue(true);

      await expect(
        service.updateBookingItems(
          '00000000-0000-4000-8000-000000000101',
          'provider-1',
          { expectedVersion: 2, items: [] },
        ),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('rejects adjustment after the job is completed', async () => {
      bookingFindOneBy.mockResolvedValue(
        booking({
          providerId: 'provider-1',
          status: BookingStatus.COMPLETED,
          completedAt: new Date(),
        }),
      );

      await expect(
        service.updateBookingItems(
          '00000000-0000-4000-8000-000000000101',
          'provider-1',
          { expectedVersion: 1, items: [] },
        ),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });
});
