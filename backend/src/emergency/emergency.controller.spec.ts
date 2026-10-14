import {
  EmergencyController,
  EmergencyAdminController,
} from './emergency.controller';
import { EmergencyService } from './emergency.service';

describe('EmergencyController & EmergencyAdminController', () => {
  let controller: EmergencyController;
  let adminController: EmergencyAdminController;
  let emergencyService: jest.Mocked<EmergencyService>;

  const principal = {
    userId: 'user-emergency-1',
    role: 'customer',
  } as any;

  const mockRequest = {
    authorizationPrincipal: principal,
  } as any;

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
      const mockResult = {
        bookingId: 'book-em-1',
        status: 'DISPATCHING',
      } as any;
      emergencyService.createEmergency.mockResolvedValue(mockResult);

      const dto = {
        serviceCategoryId: 'cat-emergency-plumbing',
        locationLat: 12.97,
        locationLng: 77.59,
        lineItems: [],
      } as any;

      const result = await controller.create(mockRequest, dto, 'idem-key-999');

      expect(emergencyService.createEmergency).toHaveBeenCalledWith(
        'user-emergency-1',
        dto,
        'idem-key-999',
      );
      expect(result).toBe(mockResult);
    });

    it('defaults idempotencyKey to empty string when not provided', async () => {
      emergencyService.createEmergency.mockResolvedValue({} as any);

      await controller.create(mockRequest, {} as any, undefined);

      expect(emergencyService.createEmergency).toHaveBeenCalledWith(
        'user-emergency-1',
        expect.anything(),
        '',
      );
    });
  });

  describe('EmergencyController.status', () => {
    it('retrieves emergency status for given bookingId', async () => {
      const mockStatus = { bookingId: 'book-em-1', isEmergency: true } as any;
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
      const mockDispatches = [{ id: 'disp-1' }, { id: 'disp-2' }] as any;
      emergencyService.listActiveDispatches.mockResolvedValue(mockDispatches);

      const result = await adminController.dispatches();

      expect(emergencyService.listActiveDispatches).toHaveBeenCalled();
      expect(result).toBe(mockDispatches);
    });
  });
});
