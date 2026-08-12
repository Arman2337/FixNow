import { Test, TestingModule } from '@nestjs/testing';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './bookings.dto';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { Booking } from './domain/booking.entity';
import { CACHE_MANAGER } from '@nestjs/cache-manager';

describe('BookingsController', () => {
  let controller: BookingsController;
  let service: BookingsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [BookingsController],
      providers: [
        {
          provide: BookingsService,
          useValue: {
            create: jest.fn(),
            acceptBooking: jest.fn(),
            updateStatus: jest.fn(),
            cancelBooking: jest.fn(),
            getBookingHistory: jest.fn(),
          },
        },
        {
          provide: CACHE_MANAGER,
          useValue: {
            get: jest.fn(),
            set: jest.fn(),
          },
        }
      ],
    }).compile();

    controller = module.get<BookingsController>(BookingsController);
    service = module.get<BookingsService>(BookingsService);
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
        locationLng: -74.0060,
      };
      
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.customerId = 'user-id';
      mockBooking.serviceCategoryId = dto.serviceCategoryId;
      mockBooking.description = dto.description;
      mockBooking.locationLat = dto.locationLat;
      mockBooking.locationLng = dto.locationLng;
      mockBooking.status = BookingStatus.REQUESTED;

      jest.spyOn(service, 'create').mockResolvedValue(mockBooking);

      const req: any = {
        authorizationPrincipal: { userId: 'user-id' },
      };

      const result = await controller.create(req, dto);

      expect(service.create).toHaveBeenCalledWith('user-id', dto);
      expect(result.booking).toEqual(mockBooking);
    });
  });

  describe('accept', () => {
    it('should call acceptBooking on service', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.status = BookingStatus.ASSIGNED;

      jest.spyOn(service, 'acceptBooking').mockResolvedValue(mockBooking);

      const req: any = {
        authorizationPrincipal: { userId: 'provider-id' },
      };

      const result = await controller.accept('booking-id', req);

      expect(service.acceptBooking).toHaveBeenCalledWith('booking-id', 'provider-id');
      expect(result.booking).toEqual(mockBooking);
    });
  });

  describe('updateStatus', () => {
    it('should call updateStatus on service', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.status = BookingStatus.EN_ROUTE;

      jest.spyOn(service, 'updateStatus').mockResolvedValue(mockBooking);

      const req: any = {
        authorizationPrincipal: { userId: 'provider-id' },
      };

      const result = await controller.updateStatus('booking-id', req, { status: BookingStatus.EN_ROUTE });

      expect(service.updateStatus).toHaveBeenCalledWith('booking-id', 'provider-id', BookingStatus.EN_ROUTE);
      expect(result.booking).toEqual(mockBooking);
    });
  });

  describe('cancel', () => {
    it('should call cancelBooking on service', async () => {
      const mockBooking = new Booking();
      mockBooking.id = 'booking-id';
      mockBooking.status = BookingStatus.CANCELLED;

      jest.spyOn(service, 'cancelBooking').mockResolvedValue(mockBooking);

      const req: any = {
        authorizationPrincipal: { userId: 'user-id' },
      };

      const result = await controller.cancel('booking-id', req, { reason: 'reason' });

      expect(service.cancelBooking).toHaveBeenCalledWith('booking-id', 'user-id', 'reason');
      expect(result.booking).toEqual(mockBooking);
    });
  });

  describe('getHistory', () => {
    it('should call getBookingHistory on service', async () => {
      const mockBooking = new Booking();
      jest.spyOn(service, 'getBookingHistory').mockResolvedValue([mockBooking]);

      const req: any = {
        authorizationPrincipal: { userId: 'user-id', roles: ['customer'] },
      };

      const result = await controller.getHistory(req, { limit: 5, offset: 0 });

      expect(service.getBookingHistory).toHaveBeenCalledWith('user-id', false, 5, 0);
      expect(result.bookings).toEqual([mockBooking]);
    });
  });
});
