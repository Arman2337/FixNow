import { Test, TestingModule } from '@nestjs/testing';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './bookings.dto';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { Booking } from './domain/booking.entity';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
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

      createMock.mockResolvedValue(mockBooking);
      const req = requestFor('user-id');

      const result = await controller.create(req, dto, 'request-key-123');

      expect(createMock).toHaveBeenCalledWith(
        'user-id',
        dto,
        'request-key-123',
      );
      expect(result.booking).toMatchObject({ id: mockBooking.id });
    });
  });

  describe('accept', () => {
    it('should call acceptBooking on service', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
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
      );
      expect(result.booking).toMatchObject({ id: mockBooking.id });
    });
  });

  describe('reschedule', () => {
    it('should call rescheduleBooking on service', async () => {
      const mockBooking = completeBooking(new Booking());
      mockBooking.id = 'booking-id';
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
});
