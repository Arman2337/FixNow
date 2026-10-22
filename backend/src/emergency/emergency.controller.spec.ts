import {
  EmergencyController,
  EmergencyAdminController,
} from './emergency.controller';
import {
  EmergencyService,
  type EmergencyCreationResult,
  type EmergencyStatusResult,
} from './emergency.service';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import type { CreateBookingDto } from '../bookings/bookings.dto';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';

describe('EmergencyController & EmergencyAdminController', () => {
  let controller: EmergencyController;
  let adminController: EmergencyAdminController;
  let emergencyService: jest.Mocked<EmergencyService>;

  const principal: AuthorizationPrincipal = {
    userId: 'user-emergency-1',
    role: 'customer',
  } as unknown as AuthorizationPrincipal;

  const mockRequest: AuthorizedRequest = {
    authorizationPrincipal: principal,
  } as unknown as AuthorizedRequest;

  beforeEach(() => {
    emergencyService = {
      createEmergency: jest.fn(),
      getStatus: jest.fn(),
      listActiveDispatches: jest.fn(),
    } as unknown as jest.Mocked<EmergencyService>;

    controller = new EmergencyController(emergencyService);
    adminController = new EmergencyAdminController(emergencyService);
  });

  describe('EmergencyController.create', () => {
    it('creates an emergency request and passes idempotencyKey', async () => {
      const mockResult: EmergencyCreationResult = {
        bookingId: 'book-em-1',
        status: BookingStatus.DISPATCHING,
        currentWave: 1,
        fallbackRequired: false,
        guidance: null,
        eligibleCount: 3,
      };
      emergencyService.createEmergency.mockResolvedValue(mockResult);

      const dto = {
        serviceCategoryId: 'cat-emergency-plumbing',
        locationLat: 12.97,
        locationLng: 77.59,
        lineItems: [],
      } as unknown as CreateBookingDto;

      const result = await controller.create(mockRequest, dto, 'idem-key-999');

      expect(emergencyService.createEmergency).toHaveBeenCalledWith(
        'user-emergency-1',
        dto,
        'idem-key-999',
      );
      expect(result).toBe(mockResult);
    });

    it('defaults idempotencyKey to empty string when not provided', async () => {
      const mockResult: EmergencyCreationResult = {
        bookingId: 'book-em-1',
        status: BookingStatus.DISPATCHING,
        currentWave: 1,
        fallbackRequired: false,
        guidance: null,
        eligibleCount: 3,
      };
      emergencyService.createEmergency.mockResolvedValue(mockResult);

      await controller.create(
        mockRequest,
        {} as unknown as CreateBookingDto,
        undefined,
      );

      expect(emergencyService.createEmergency).toHaveBeenCalledWith(
        'user-emergency-1',
        expect.anything(),
        '',
      );
    });
  });

  describe('EmergencyController.status', () => {
    it('retrieves emergency status for given bookingId', async () => {
      const mockStatus: EmergencyStatusResult = {
        bookingId: 'book-em-1',
        status: BookingStatus.DISPATCHING,
        currentWave: 1,
        fallbackRequired: false,
        guidance: null,
        eligibleCount: 3,
        isEmergency: true,
      } as unknown as EmergencyStatusResult;
      emergencyService.getStatus.mockResolvedValue(mockStatus);

      const result = await controller.status(mockRequest, {
        bookingId: 'book-em-1',
      });

      expect(emergencyService.getStatus).toHaveBeenCalledWith(
        'book-em-1',
        principal,
      );
      expect(result).toBe(mockStatus);
    });
  });

  describe('EmergencyAdminController.dispatches', () => {
    it('lists active emergency dispatches for administrators', async () => {
      const mockDispatches = [
        {
          bookingId: 'disp-1',
          customerId: 'cust-1',
          categoryName: 'Plumbing',
          status: BookingStatus.REQUESTED,
          currentWave: 1,
          lastEscalatedAt: null,
          createdAt: new Date(),
        },
      ];
      emergencyService.listActiveDispatches.mockResolvedValue(mockDispatches);

      const result = await adminController.dispatches();

      expect(emergencyService.listActiveDispatches).toHaveBeenCalled();
      expect(result).toBe(mockDispatches);
    });
  });
});
