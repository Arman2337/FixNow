import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { BookingsService } from './bookings.service';
import { Booking } from './domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { Repository } from 'typeorm';

describe('BookingsService', () => {
  let service: BookingsService;
  let repository: jest.Mocked<Repository<Booking>>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        {
          provide: getRepositoryToken(Booking),
          useValue: {
            save: jest.fn(),
            findOne: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
    repository = module.get(getRepositoryToken(Booking));
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create and save a new booking', async () => {
      const input = {
        serviceCategoryId: 'category-id',
        description: 'Test booking',
        locationLat: 40.7128,
        locationLng: -74.0060,
      };

      const mockSavedBooking = new Booking();
      mockSavedBooking.id = 'booking-id';
      mockSavedBooking.customerId = 'customer-id';
      mockSavedBooking.serviceCategoryId = input.serviceCategoryId;
      mockSavedBooking.description = input.description;
      mockSavedBooking.locationLat = input.locationLat;
      mockSavedBooking.locationLng = input.locationLng;
      mockSavedBooking.status = BookingStatus.REQUESTED;
      
      repository.save.mockResolvedValue(mockSavedBooking);

      const result = await service.create('customer-id', input);

      expect(repository.save).toHaveBeenCalled();
      const savedObj = repository.save.mock.calls[0][0];
      expect(savedObj.customerId).toBe('customer-id');
      expect(savedObj.serviceCategoryId).toBe(input.serviceCategoryId);
      expect(savedObj.status).toBe(BookingStatus.REQUESTED); // Validated by class constructor
      expect(result).toEqual(mockSavedBooking);
    });
  });

  describe('acceptBooking', () => {
    it('should accept a booking and transition to ASSIGNED', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.status = BookingStatus.REQUESTED;
      mockBooking.transitionTo = jest.fn().mockImplementation(function (status) { this.status = status; });
      
      repository.findOne.mockResolvedValue(mockBooking);
      repository.save.mockResolvedValue(mockBooking);

      const result = await service.acceptBooking('booking-id', 'provider-id');

      expect(mockBooking.providerId).toBe('provider-id');
      expect(mockBooking.transitionTo).toHaveBeenCalledWith(BookingStatus.ASSIGNED);
      expect(repository.save).toHaveBeenCalledWith(mockBooking);
      expect(result.status).toBe(BookingStatus.ASSIGNED);
    });

    it('should throw ConflictException if booking is not REQUESTED', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.status = BookingStatus.ASSIGNED;
      
      repository.findOne.mockResolvedValue(mockBooking);

      await expect(service.acceptBooking('booking-id', 'provider-id')).rejects.toThrow('Booking is no longer available');
    });

    it('should throw ConflictException on OptimisticLockVersionMismatchError', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.status = BookingStatus.REQUESTED;
      mockBooking.transitionTo = jest.fn();
      
      repository.findOne.mockResolvedValue(mockBooking);
      
      const error = new Error('Lock error');
      error.name = 'OptimisticLockVersionMismatchError';
      repository.save.mockRejectedValue(error);

      await expect(service.acceptBooking('booking-id', 'provider-id')).rejects.toThrow('Booking was already accepted by another provider');
    });
  });

  describe('updateStatus', () => {
    it('should update booking status if provider matches', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.providerId = 'provider-id';
      mockBooking.status = BookingStatus.ASSIGNED;
      mockBooking.transitionTo = jest.fn().mockImplementation(function (status) { this.status = status; });
      
      repository.findOne.mockResolvedValue(mockBooking);
      repository.save.mockResolvedValue(mockBooking);

      const result = await service.updateStatus('booking-id', 'provider-id', BookingStatus.EN_ROUTE);

      expect(mockBooking.transitionTo).toHaveBeenCalledWith(BookingStatus.EN_ROUTE);
      expect(repository.save).toHaveBeenCalledWith(mockBooking);
      expect(result.status).toBe(BookingStatus.EN_ROUTE);
    });

    it('should throw ForbiddenException if provider does not match', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.providerId = 'other-provider-id';
      mockBooking.status = BookingStatus.ASSIGNED;
      
      repository.findOne.mockResolvedValue(mockBooking);

      await expect(service.updateStatus('booking-id', 'provider-id', BookingStatus.EN_ROUTE)).rejects.toThrow('You are not assigned to this booking');
    });
  });

  describe('cancelBooking', () => {
    it('should cancel booking and redact if needed', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'customer-id';
      mockBooking.status = BookingStatus.REQUESTED;
      mockBooking.transitionTo = jest.fn().mockImplementation(function (status, reason) { 
        this.status = status; 
        this.cancellationReason = reason; 
      });
      
      repository.findOne.mockResolvedValue(mockBooking);
      repository.save.mockResolvedValue(mockBooking);

      const result = await service.cancelBooking('booking-id', 'customer-id', 'Changed mind');

      expect(mockBooking.transitionTo).toHaveBeenCalledWith(BookingStatus.CANCELLED, 'Changed mind');
      expect(result.status).toBe(BookingStatus.CANCELLED);
    });

    it('should throw ForbiddenException if unauthorized', async () => {
      const mockBooking = new Booking();
      mockBooking.customerId = 'customer-id';
      mockBooking.providerId = 'provider-id';
      
      repository.findOne.mockResolvedValue(mockBooking);

      await expect(service.cancelBooking('booking-id', 'other-id', 'Reason')).rejects.toThrow('You are not authorized to cancel this booking');
    });
  });

  describe('getBookingHistory', () => {
    it('should fetch history for customer without redaction', async () => {
      const mockBooking = new Booking();
      mockBooking.locationLat = 40.0;
      mockBooking.locationLng = -70.0;
      mockBooking.status = BookingStatus.COMPLETED;

      const mockQueryBuilder = {
        where: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([mockBooking]),
      };

      repository.createQueryBuilder.mockReturnValue(mockQueryBuilder as any);

      const result = await service.getBookingHistory('customer-id', false, 10, 0);

      expect(mockQueryBuilder.where).toHaveBeenCalledWith('booking.customerId = :userId', { userId: 'customer-id' });
      expect(result[0].locationLat).toBe(40.0);
    });

    it('should fetch history for provider with redaction', async () => {
      const mockBooking = new Booking();
      mockBooking.locationLat = 40.0;
      mockBooking.locationLng = -70.0;
      mockBooking.status = BookingStatus.COMPLETED;

      const mockQueryBuilder = {
        where: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([mockBooking]),
      };

      repository.createQueryBuilder.mockReturnValue(mockQueryBuilder as any);

      const result = await service.getBookingHistory('provider-id', true, 10, 0);

      expect(mockQueryBuilder.where).toHaveBeenCalledWith('booking.providerId = :userId', { userId: 'provider-id' });
      expect(result[0].locationLat).toBe(0); // Redacted
    });
  });
});
