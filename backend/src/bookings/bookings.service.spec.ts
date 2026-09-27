/* Jest service mocks are intentionally asserted as detached functions. */
/* eslint-disable @typescript-eslint/unbound-method */
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import type { DataSource, EntityManager, Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type { MatchingService } from '../matching/matching.service';
import type { ProviderCapacityService } from '../providers/availability/provider-capacity.service';
import { BookingsService } from './bookings.service';
import { BookingEvent } from './domain/booking-event.entity';
import { Booking } from './domain/booking.entity';
import { PaymentOrder } from '../payments/domain/payment-order.entity';
import { SubServiceEntity } from '../services/sub-service.entity';

/**
 * The server-side price catalogue. Tests select entries by `subServiceId`;
 * every `unitPriceMinor` in a booking MUST come from here, never from the
 * request body. See SEC-001.
 */
const CATEGORY_ID = '00000000-0000-4000-8000-000000000010';
const sub = (
  id: string,
  name: string,
  priceMinor: number | null,
  minutes: number | null = null,
  categoryId = CATEGORY_ID,
  isActive = true,
): SubServiceEntity =>
  Object.assign(new SubServiceEntity(), {
    id,
    name,
    categoryId,
    priceMinor,
    currency: 'INR',
    estimatedDurationMinutes: minutes,
    isActive,
  });

const CATALOGUE: SubServiceEntity[] = [
  sub('plumb-3', 'Shower & Water Pipe Leakage', 24900, 45),
  sub('plumb-1', 'Tap & Mixer Repair', 14900, 30),
  sub('ac-1', 'AC Servicing', 89900, 60),
  sub('no-price', 'Custom Diagnosis', null),
  sub('inactive-1', 'Retired Service', 99900, 20, CATEGORY_ID, false),
  sub('other-cat', 'Other Category Service', 5000, 10, 'other-category'),
];

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
  let capacity: jest.Mocked<ProviderCapacityService>;
  const capacityAssert = jest.fn().mockResolvedValue(undefined);
  const capacitySync = jest.fn().mockResolvedValue(undefined);
  let subServiceFindBy: jest.Mock;

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
    subServiceFindBy = jest.fn().mockResolvedValue(CATALOGUE);
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
    subServiceFindBy = jest.fn().mockResolvedValue(CATALOGUE);
    const subServiceRepository = {
      findBy: subServiceFindBy,
    } as unknown as jest.Mocked<Repository<SubServiceEntity>>;
    manager = {
      getRepository: jest.fn((entity: unknown) => {
        if (entity === Booking) return bookingRepository;
        if (entity === BookingEvent) return eventRepository;
        if (entity === PaymentOrder) return orderRepository;
        if (entity === SubServiceEntity) return subServiceRepository;
        return eventRepository;
      }),
    } as unknown as jest.Mocked<EntityManager>;
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
      isProviderEligible: jest.fn(),
      findProviderDistance: jest.fn(),
    } as unknown as jest.Mocked<MatchingService>;
    capacity = {
      assertCanAccept: capacityAssert,
      syncAvailabilityForWorkload: capacitySync,
    } as unknown as jest.Mocked<ProviderCapacityService>;
    service = new BookingsService(dataSource, matchingService, capacity);
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

  it('prices items from the catalogue and recomputes totals server-side', async () => {
    bookingFindOneBy.mockResolvedValue(null);
    bookingSave.mockImplementation((value: Booking) => Promise.resolve(value));

    const result = await service.create(
      '00000000-0000-4000-8000-000000000001',
      {
        serviceCategoryId: CATEGORY_ID,
        description: 'Repair a leaking pipe',
        locationLat: 22.3,
        locationLng: 73.2,
        // The client selects catalogue entries and quantities ONLY.
        items: [
          { subServiceId: 'plumb-3', quantity: 2 },
          { subServiceId: 'plumb-1', quantity: 1 },
        ],
      },
      'request-key-123',
    );

    // 2 x 24900 + 1 x 14900 = 64700; GST 18% = 11646; duration 2x45 + 30 = 120.
    // Every price came from CATALOGUE, not from the request.
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
    bookingSave.mockImplementation((value: Booking) => Promise.resolve(value));

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
    matchingService.isProviderEligible.mockResolvedValue(false);

    await expect(
      service.acceptBooking(
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000002',
        1,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  // BUG-007: eligibility is judged for the provider who is asking, not by
  // looking for them in a distance-ordered shortlist.
  it('judges acceptance eligibility for the asking provider, not a shortlist', async () => {
    const target = booking();
    bookingFindOneBy.mockResolvedValue(target);
    stubTransition(target);
    matchingService.isProviderEligible.mockResolvedValue(true);

    await service.acceptBooking(
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000002',
      1,
    );

    expect(matchingService.isProviderEligible).toHaveBeenCalledWith(
      '00000000-0000-4000-8000-000000000002',
      target.locationLat,
      target.locationLng,
      target.serviceCategoryId,
    );
    // The capped fan-out must not be consulted to decide eligibility.
    expect(matchingService.findEligibleProviders).not.toHaveBeenCalled();
  });

  it('rejects malformed history cursors', async () => {
    await expect(
      service.getBookingHistory('customer-id', 20, 'not-json'),
    ).rejects.toThrow('Invalid booking history cursor');
  });

  describe('getBookingForUser', () => {
    const CUSTOMER_ID = '00000000-0000-4000-8000-000000000001';
    const PROVIDER_ID = '00000000-0000-4000-8000-000000000002';
    const BOOKING_ID = '00000000-0000-4000-8000-000000000101';

    it('keeps the destination on an active job read by the assigned provider', async () => {
      bookingFindOneBy.mockResolvedValue(
        booking({ status: BookingStatus.EN_ROUTE, providerId: PROVIDER_ID }),
      );

      const result = await service.getBookingForUser(BOOKING_ID, PROVIDER_ID);

      expect(result.locationLat).toBe(22.3);
      expect(result.locationLng).toBe(73.2);
    });

    it('strips the destination once the job is terminal for the provider', async () => {
      bookingFindOneBy.mockResolvedValue(
        booking({ status: BookingStatus.COMPLETED, providerId: PROVIDER_ID }),
      );

      const result = await service.getBookingForUser(BOOKING_ID, PROVIDER_ID);

      expect(result.locationLat).toBeNull();
      expect(result.locationLng).toBeNull();
    });

    it('always returns the destination to the customer', async () => {
      bookingFindOneBy.mockResolvedValue(
        booking({ status: BookingStatus.COMPLETED, providerId: PROVIDER_ID }),
      );

      const result = await service.getBookingForUser(BOOKING_ID, CUSTOMER_ID);

      expect(result.locationLat).toBe(22.3);
      expect(result.locationLng).toBe(73.2);
    });

    it('rejects a reader who is not a booking participant', async () => {
      bookingFindOneBy.mockResolvedValue(booking());

      await expect(
        service.getBookingForUser(
          BOOKING_ID,
          '00000000-0000-4000-8000-000000000099',
        ),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  it('returns only requests for which the provider is currently eligible', async () => {
    const first = booking({ id: '00000000-0000-4000-8000-000000000201' });
    const second = booking({ id: '00000000-0000-4000-8000-000000000202' });
    bookingFind.mockResolvedValue([first, second]);
    // BUG-004: eligibility is now one scoped lookup per candidate rather than
    // a 50-entry fan-out searched for the asking provider.
    matchingService.findProviderDistance
      .mockResolvedValueOnce(2.4)
      .mockResolvedValueOnce(null);

    await expect(
      service.getAvailableRequests('provider-id', 20),
    ).resolves.toEqual({
      bookings: [{ booking: first, distanceKm: 2.4 }],
    });
    // The rank-limited fan-out must not be consulted here either.
    expect(matchingService.findEligibleProviders).not.toHaveBeenCalled();
  });

  it('presents available work newest-first regardless of lookup completion order', async () => {
    const first = booking({ id: '00000000-0000-4000-8000-000000000201' });
    const second = booking({ id: '00000000-0000-4000-8000-000000000202' });
    bookingFind.mockResolvedValue([first, second]);
    // The second candidate resolves first; the list must still lead with the
    // first, because a bounded pool finishes out of order.
    matchingService.findProviderDistance
      .mockImplementationOnce(
        () => new Promise((resolve) => setTimeout(() => resolve(2.4), 5)),
      )
      .mockImplementationOnce(() => Promise.resolve(1.1));

    const page = await service.getAvailableRequests('provider-id', 20);

    expect(page.bookings.map((entry) => entry.booking.id)).toEqual([
      first.id,
      second.id,
    ]);
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

  /**
   * `transition()` finishes with a compare-and-set
   * (`createQueryBuilder().update().set().where().execute()`). Tests that only
   * care about what happened *before* the write need this to get past it.
   */
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
    (bookingRepository.findOneByOrFail as jest.Mock).mockResolvedValue(updated);
    return builder;
  };

  describe('updateBookingItems', () => {
    const activeJob = () =>
      booking({
        providerId: 'provider-1',
        status: BookingStatus.IN_PROGRESS,
        version: 2,
      });

    it('re-prices provider-supplied items from the catalogue', async () => {
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
          reason: 'Found a second leak while on site',
          // The provider selects a catalogue entry and a quantity only.
          items: [{ subServiceId: 'plumb-3', quantity: 2 }],
        },
      );

      // 2×24900 = 49800 subtotal; GST 8964; duration 90. Price from CATALOGUE.
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
      bookingFindOneBy.mockResolvedValue(activeJob());

      await expect(
        service.updateBookingItems(
          '00000000-0000-4000-8000-000000000101',
          'provider-1',
          { expectedVersion: 2, items: [] },
        ),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    // BUG-010: the sibling line-items path re-priced the booking with no payment
    // guard, so a provider could change the total after a payment order existed
    // and the capture then failed permanently on an amount mismatch.
    it('rejects a line-item rewrite once a payment order exists', async () => {
      orderExist.mockResolvedValue(true);
      // IN_PROGRESS, so the completed/cancelled status guard cannot be what
      // rejects this - only the payment guard can.
      bookingFindOneBy.mockResolvedValue(activeJob());

      await expect(
        service.updateBookingLineItems(
          '00000000-0000-4000-8000-000000000101',
          'provider-1',
          [
            {
              subServiceId: 'plumb-3',
              quantity: 2,
            },
          ],
          2,
        ),
      ).rejects.toThrow(/payment has started/);
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

    // ---- SEC-001: a provider must not be able to choose the price ----
    it('ignores any price smuggled through the item payload', async () => {
      bookingFindOneBy.mockResolvedValue(activeJob());
      const updated = activeJob();
      updated.version = 3;
      const builder = stubTransition(updated);

      // A caller reaching past the DTO (e.g. a hand-rolled HTTP client) tries
      // to force a price of 1 paise. The catalogue price must still win.
      await service.updateBookingItems(
        '00000000-0000-4000-8000-000000000101',
        'provider-1',
        {
          expectedVersion: 2,
          items: [
            {
              subServiceId: 'plumb-3',
              quantity: 2,
              ...({ unitPriceMinor: 1, name: 'anything' } as object),
            },
          ],
        },
      );

      const calls = builder.set.mock.calls as unknown as [
        { items: { unitPriceMinor: number }[]; totalAmountMinor: number },
      ][];
      const payload = calls[0][0];
      expect(payload.items[0].unitPriceMinor).toBe(24900);
      expect(payload.totalAmountMinor).toBe(58764);
    });

    it('refuses a catalogue entry that belongs to another category', async () => {
      bookingFindOneBy.mockResolvedValue(activeJob());
      stubTransition(activeJob());

      await expect(
        service.updateBookingItems(
          '00000000-0000-4000-8000-000000000101',
          'provider-1',
          {
            expectedVersion: 2,
            items: [{ subServiceId: 'other-cat', quantity: 1 }],
          },
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('refuses a catalogue entry that is inactive or unpriced', async () => {
      bookingFindOneBy.mockResolvedValue(activeJob());
      stubTransition(activeJob());

      await expect(
        service.updateBookingItems(
          '00000000-0000-4000-8000-000000000101',
          'provider-1',
          {
            expectedVersion: 2,
            items: [{ subServiceId: 'inactive-1', quantity: 1 }],
          },
        ),
      ).rejects.toBeInstanceOf(BadRequestException);

      await expect(
        service.updateBookingItems(
          '00000000-0000-4000-8000-000000000101',
          'provider-1',
          {
            expectedVersion: 2,
            items: [{ subServiceId: 'no-price', quantity: 1 }],
          },
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  // ---- SEC-001 at creation time ----
  describe('server-side pricing on create', () => {
    beforeEach(() => {
      bookingFindOneBy.mockResolvedValue(null);
      bookingSave.mockImplementation((value: Booking) =>
        Promise.resolve(value),
      );
    });

    it('never persists a client-supplied unit price', async () => {
      const result = await service.create(
        '00000000-0000-4000-8000-000000000001',
        {
          serviceCategoryId: CATEGORY_ID,
          description: 'Tampered request',
          locationLat: 22.3,
          locationLng: 73.2,
          items: [
            {
              subServiceId: 'ac-1',
              quantity: 1,
              // Rs 0.01 for a Rs 899 service
              ...({ unitPriceMinor: 1, name: 'free', id: 'x' } as object),
            },
          ],
        },
        'tamper-key-01',
      );

      // 89900 + 18% GST (16182) = 106082. The tampered value of 1 paise is ignored.
      expect(result.items?.[0].unitPriceMinor).toBe(89900);
      expect(result.totalAmountMinor).toBe(106082);
    });

    it('rejects a sub-service from another category', async () => {
      await expect(
        service.create(
          '00000000-0000-4000-8000-000000000001',
          {
            serviceCategoryId: CATEGORY_ID,
            description: 'Wrong category',
            locationLat: 22.3,
            locationLng: 73.2,
            items: [{ subServiceId: 'other-cat', quantity: 1 }],
          },
          'wrong-cat-key-01',
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rejects a sub-service that does not exist', async () => {
      await expect(
        service.create(
          '00000000-0000-4000-8000-000000000001',
          {
            serviceCategoryId: CATEGORY_ID,
            description: 'Ghost service',
            locationLat: 22.3,
            locationLng: 73.2,
            items: [{ subServiceId: 'does-not-exist', quantity: 1 }],
          },
          'ghost-key-000001',
        ),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
