import { ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './bookings.dto';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { Booking } from './domain/booking.entity';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { REQUIRED_PERMISSION_KEY } from '../common/authorization/authorization.decorators';
import {
  PERMISSIONS,
  PERMISSION_POLICIES,
} from '../common/authorization/permission-policies';
import type { RoleCode } from '../common/authorization/permission-policies';

describe('BookingsController', () => {
  let controller: BookingsController;
  let createMock: jest.MockedFunction<BookingsService['create']>;
  let acceptMock: jest.MockedFunction<BookingsService['acceptBooking']>;
  let updateStatusMock: jest.MockedFunction<BookingsService['updateStatus']>;
  let cancelMock: jest.MockedFunction<BookingsService['cancelBooking']>;
  let rescheduleMock: jest.Mock;
  let historyMock: jest.MockedFunction<BookingsService['getBookingHistory']>;
  let availableMock: jest.MockedFunction<
    BookingsService['getAvailableRequests']
  >;
  let getBookingMock: jest.MockedFunction<BookingsService['getBookingForUser']>;

  const requestFor = (
    userId: string,
    roles: readonly RoleCode[] = [],
  ): AuthorizedRequest =>
    ({
      authorizationPrincipal: { userId, sessionId: 'session-id', roles },
    }) as unknown as AuthorizedRequest;

  const completeBooking = (booking: Booking): Booking => {
    booking.providerId ??= null;
    booking.scheduledAt ??= null;
    booking.assignedAt ??= null;
    booking.enRouteAt ??= null;
    booking.startedAt ??= null;
    booking.completedAt ??= null;
    booking.cancelledAt ??= null;
    booking.cancellationReason ??= null;
    booking.createdAt ??= new Date('2026-08-12T00:00:00.000Z');
    booking.updatedAt ??= new Date('2026-08-12T00:00:00.000Z');
    booking.version ??= 1;
    return booking;
  };

  beforeEach(async () => {
    createMock = jest.fn();
    acceptMock = jest.fn();
    updateStatusMock = jest.fn();
    cancelMock = jest.fn();
    rescheduleMock = jest.fn();
    historyMock = jest.fn();
    availableMock = jest.fn();
    getBookingMock = jest.fn();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [BookingsController],
      providers: [
        {
          provide: BookingsService,
          useValue: {
            create: createMock,
            acceptBooking: acceptMock,
            updateStatus: updateStatusMock,
            cancelBooking: cancelMock,
            rescheduleBooking: rescheduleMock,
            getBookingHistory: historyMock,
            getAvailableRequests: availableMock,
            getBookingForUser: getBookingMock,
          },
        },
      ],
    }).compile();

    controller = module.get<BookingsController>(BookingsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('create', () => {
    it('should create a new booking', async () => {
      const dto: CreateBookingDto = {
        serviceCategoryId: 'category-id',
        description: 'Test booking',
        locationLat: 40.7128,
        locationLng: -74.006,
      };

      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'user-id';
      mockBooking.serviceCategoryId = dto.serviceCategoryId;
      mockBooking.description = dto.description;
      mockBooking.locationLat = dto.locationLat;
      mockBooking.locationLng = dto.locationLng;
      mockBooking.status = BookingStatus.REQUESTED;

      createMock.mockResolvedValue({
        booking: mockBooking,
        eligibleProviderCount: 3,
        noProviderAvailable: false,
      });
      const req = requestFor('user-id');

      const result = await controller.create(req, dto, 'request-key-123');

      expect(createMock).toHaveBeenCalledWith(
        'user-id',
        dto,
        'request-key-123',
      );
      expect(result.booking).toMatchObject({ id: mockBooking.id });
      // BUG-014: the creation response carries supply, so a client can tell
      // "searching" from "nobody is available".
      expect(result.eligibleProviderCount).toBe(3);
      expect(result.noProviderAvailable).toBe(false);
    });
  });

  describe('accept', () => {
    it('should call acceptBooking on service', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'customer-id';
      mockBooking.providerId = 'provider-id';
      mockBooking.status = BookingStatus.ASSIGNED;

      acceptMock.mockResolvedValue(mockBooking);
      const req = requestFor('provider-id');

      const result = await controller.accept('booking-id', req, {
        expectedVersion: 1,
      });

      expect(acceptMock).toHaveBeenCalledWith('booking-id', 'provider-id', 1);
      expect(result.booking).toMatchObject({ id: mockBooking.id });
    });
  });

  describe('updateStatus', () => {
    it('should call updateStatus on service', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'customer-id';
      mockBooking.providerId = 'provider-id';
      mockBooking.status = BookingStatus.EN_ROUTE;

      updateStatusMock.mockResolvedValue(mockBooking);
      const req = requestFor('provider-id');

      const result = await controller.updateStatus('booking-id', req, {
        status: BookingStatus.EN_ROUTE,
        expectedVersion: 2,
      });

      expect(updateStatusMock).toHaveBeenCalledWith(
        'booking-id',
        'provider-id',
        BookingStatus.EN_ROUTE,
        2,
      );
      expect(result.booking).toMatchObject({ id: mockBooking.id });
    });
  });

  describe('cancel', () => {
    it('should call cancelBooking on service', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'user-id';
      mockBooking.providerId = 'provider-id';
      mockBooking.status = BookingStatus.CANCELLED;

      cancelMock.mockResolvedValue(mockBooking);
      const req = requestFor('user-id');

      const result = await controller.cancel('booking-id', req, {
        reason: 'reason',
        expectedVersion: 1,
      });

      expect(cancelMock).toHaveBeenCalledWith(
        'booking-id',
        'user-id',
        'reason',
        1,
        // BUG-020: a customer cancelling has no abandonment code to give.
        undefined,
      );
      expect(result.booking).toMatchObject({ id: mockBooking.id });
    });

    // BUG-020: a provider abandoning a job they started sends a code, and the
    // controller passes it through rather than dropping it.
    it('passes an abandonment reason code through to the service', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'customer-id';
      mockBooking.providerId = 'provider-id';
      cancelMock.mockResolvedValue(mockBooking);

      await controller.cancel('booking-id', requestFor('provider-id'), {
        reason: 'The work is not what was described',
        expectedVersion: 4,
        abandonmentReason: 'JOB_MISDESCRIBED',
      });

      expect(cancelMock).toHaveBeenCalledWith(
        'booking-id',
        'provider-id',
        'The work is not what was described',
        4,
        'JOB_MISDESCRIBED',
      );
    });
  });

  describe('reschedule', () => {
    it('should call rescheduleBooking on service', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'user-id';
      mockBooking.providerId = 'provider-id';
      mockBooking.scheduledAt = new Date('2026-08-30T10:00:00.000Z');

      rescheduleMock.mockResolvedValue(mockBooking);
      const req = requestFor('user-id');

      const result = await controller.reschedule('booking-id', req, {
        newScheduledAt: '2026-08-30T10:00:00.000Z',
        reason: 'Family emergency',
        expectedVersion: 1,
      });

      expect(rescheduleMock).toHaveBeenCalledWith(
        'booking-id',
        'user-id',
        '2026-08-30T10:00:00.000Z',
        1,
        'Family emergency',
      );
      expect(result.booking).toMatchObject({ id: mockBooking.id });
    });
  });

  describe('getBooking', () => {
    it('returns the single booking to a participant', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'user-id';
      mockBooking.status = BookingStatus.EN_ROUTE;
      getBookingMock.mockResolvedValue(mockBooking);
      const req = requestFor('user-id', ['customer']);

      const result = await controller.getBooking(req, 'booking-id');

      expect(getBookingMock).toHaveBeenCalledWith('booking-id', 'user-id');
      expect(result.booking).toMatchObject({ id: 'booking-id' });
    });
  });

  describe('getHistory', () => {
    it('should call getBookingHistory on service', async () => {
      const mockBooking = completeBooking(new Booking());
      historyMock.mockResolvedValue({
        bookings: [mockBooking],
        nextCursor: 'next-page',
      });
      const req = requestFor('user-id', ['customer']);

      const result = await controller.getHistory(req, {
        limit: 5,
        cursor: 'cursor-value',
      });

      expect(historyMock).toHaveBeenCalledWith('user-id', 5, 'cursor-value');
      expect(result.bookings).toHaveLength(1);
      expect(result.nextCursor).toBe('next-page');
    });
  });

  describe('getAvailableRequests', () => {
    it('returns provider-safe request previews', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = '00000000-0000-4000-8000-000000000201';
      mockBooking.status = BookingStatus.REQUESTED;
      availableMock.mockResolvedValue({
        bookings: [{ booking: mockBooking, distanceKm: 1.8 }],
      });

      const result = await controller.getAvailableRequests(
        requestFor('provider-id', ['verified_provider']),
        { limit: 10 },
      );

      expect(availableMock).toHaveBeenCalledWith('provider-id', 10);
      expect(result.bookings).toEqual([
        expect.objectContaining({
          id: mockBooking.id,
          distanceKm: 1.8,
          status: BookingStatus.REQUESTED,
        }),
      ]);
      expect(result.bookings[0]).not.toHaveProperty('locationLat');
      expect(result.bookings[0]).not.toHaveProperty('customerId');
    });
  });

  // A price-affecting mutation authorised by a permission named "update status"
  // reads as harmless during review, and an OTP was gated on a read permission.
  // These assert the wiring so the names cannot drift back.
  // SEC-002: every self-scoped booking route now has to prove, against the
  // booking's real party columns, that the caller is one of its parties. These
  // assert the proof bites — a handler that compared nothing would still
  // return the booking and `OwnershipProofInterceptor` would 403 it.
  describe('SEC-002 ownership discharge', () => {
    const foreignBooking = (overrides: Partial<Booking> = {}): Booking =>
      Object.assign(completeBooking(new Booking()), {
        id: 'booking-id',
        customerId: 'someone-else',
        providerId: 'another-provider',
        status: BookingStatus.ASSIGNED,
        ...overrides,
      });

    it('refuses to accept a booking the caller is not the assignee of', async () => {
      acceptMock.mockResolvedValue(foreignBooking());
      await expect(
        controller.accept('booking-id', requestFor('provider-id'), {
          expectedVersion: 1,
        }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('refuses a status update on a booking assigned to someone else', async () => {
      updateStatusMock.mockResolvedValue(foreignBooking());
      await expect(
        controller.updateStatus('booking-id', requestFor('provider-id'), {
          status: BookingStatus.EN_ROUTE,
          expectedVersion: 1,
        }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('refuses a cancel on a booking the caller is not a party to', async () => {
      cancelMock.mockResolvedValue(foreignBooking());
      await expect(
        controller.cancel('booking-id', requestFor('user-id'), {
          reason: 'reason',
          expectedVersion: 1,
        }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('refuses to read a booking the caller is not a party to', async () => {
      getBookingMock.mockResolvedValue(foreignBooking());
      await expect(
        controller.getBooking(requestFor('user-id'), 'booking-id'),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('lets the assigned provider, but not the customer, drive a status update', async () => {
      const booking = foreignBooking({ providerId: 'provider-id' });
      updateStatusMock.mockResolvedValue(booking);
      await expect(
        controller.updateStatus('booking-id', requestFor('provider-id'), {
          status: BookingStatus.EN_ROUTE,
          expectedVersion: 1,
        }),
      ).resolves.toMatchObject({ booking: { id: 'booking-id' } });

      await expect(
        controller.updateStatus('booking-id', requestFor('customer-id'), {
          status: BookingStatus.EN_ROUTE,
          expectedVersion: 1,
        }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('authorization metadata', () => {
    const permissionFor = (methodName: string): unknown => {
      const descriptor = Object.getOwnPropertyDescriptor(
        BookingsController.prototype,
        methodName,
      );
      const handler: unknown = descriptor?.value;
      if (typeof handler !== 'function') {
        throw new Error(`BookingsController.${methodName} is not defined`);
      }
      return Reflect.getMetadata(REQUIRED_PERMISSION_KEY, handler);
    };

    it('gates the priced-item routes on a permission that says so', () => {
      expect(permissionFor('updateItems')).toBe(PERMISSIONS.bookingManageItems);
      expect(permissionFor('updateLineItems')).toBe(
        PERMISSIONS.bookingManageItems,
      );
    });

    it('keeps the status route on the status permission', () => {
      expect(permissionFor('updateStatus')).toBe(
        PERMISSIONS.bookingUpdateStatus,
      );
    });

    it('does not let a read permission issue the service-start OTP', () => {
      expect(permissionFor('serviceStartOtp')).toBe(
        PERMISSIONS.bookingServiceStartOtp,
      );
      expect(PERMISSIONS.bookingServiceStartOtp).not.toBe(
        PERMISSIONS.bookingHistoryReadSelf,
      );
    });

    it('restricts the new permissions to the right roles and scope', () => {
      expect(PERMISSION_POLICIES[PERMISSIONS.bookingManageItems]).toEqual({
        roles: ['verified_provider'],
        relationship: 'self',
      });
      expect(PERMISSION_POLICIES[PERMISSIONS.bookingServiceStartOtp]).toEqual({
        roles: ['customer'],
        relationship: 'self',
      });
    });
  });
});
