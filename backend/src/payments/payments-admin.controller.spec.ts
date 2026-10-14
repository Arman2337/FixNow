import { BadRequestException } from '@nestjs/common';
import { PaymentsAdminController } from './payments-admin.controller';
import { PaymentsService } from './payments.service';

describe('PaymentsAdminController', () => {
  let controller: PaymentsAdminController;
  let service: jest.Mocked<PaymentsService>;

  const req = {
    authorizationPrincipal: {
      userId: 'admin-usr-1',
      role: 'operations_administrator',
    },
  } as any;

  beforeEach(() => {
    service = {
      refundOrder: jest.fn(),
    } as unknown as jest.Mocked<PaymentsService>;

    controller = new PaymentsAdminController(service);
  });

  describe('refund', () => {
    it('executes refund when Idempotency-Key header is present', async () => {
      const mockResult = { refundId: 'ref-1', status: 'PROCESSED' } as any;
      service.refundOrder.mockResolvedValue(mockResult);

      const result = await controller.refund('ord-100', req, 'key-abc-123', {
        amountMinor: 25000,
        reason: 'Customer complaint resolution',
      });

      expect(service.refundOrder).toHaveBeenCalledWith(
        'admin-usr-1',
        'ord-100',
        {
          amountMinor: 25000,
          reason: 'Customer complaint resolution',
          requestKey: 'key-abc-123',
        },
      );
      expect(result).toBe(mockResult);
    });

    it('throws BadRequestException when Idempotency-Key header is missing or empty', async () => {
      await expect(
        controller.refund('ord-100', req, undefined, {
          amountMinor: 25000,
          reason: 'Test',
        }),
      ).rejects.toThrow(BadRequestException);

      await expect(
        controller.refund('ord-100', req, '   ', {
          amountMinor: 25000,
          reason: 'Test',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
