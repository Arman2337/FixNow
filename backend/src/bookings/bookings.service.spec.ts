import { ConflictException, ForbiddenException } from '@nestjs/common';
import type { DataSource, EntityManager, Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type { MatchingService } from '../matching/matching.service';
import { BookingsService } from './bookings.service';
import { BookingEvent } from './domain/booking-event.entity';
import { Booking } from './domain/booking.entity';

describe('BookingsService', () => {
  let service: BookingsService;
  let bookingRepository: jest.Mocked<Repository<Booking>>;
  let eventRepository: jest.Mocked<Repository<BookingEvent>>;
  let dataSource: jest.Mocked<DataSource>;
  let manager: jest.Mocked<EntityManager>;
  let matchingService: jest.Mocked<MatchingService>;
  let bookingFindOneBy: jest.Mock;
  let bookingSave: jest.Mock;
  let eventSave: jest.Mock;

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
    bookingSave = jest.fn();
    eventSave = jest.fn().mockResolvedValue(new BookingEvent());
    bookingRepository = {
      findOneBy: bookingFindOneBy,
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
    dataSource = {
      getRepository: jest.fn(() => bookingRepository),
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
});
