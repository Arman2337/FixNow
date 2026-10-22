import { BadRequestException } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import type { PaymentOrderContract } from '../../../shared/payments.types';

describe('PaymentsController', () => {
  let controller: PaymentsController;
  let service: jest.Mocked<PaymentsService>;

  const principal: AuthorizationPrincipal = {
    userId: 'user-cust-1',
    role: 'customer',
  } as unknown as AuthorizationPrincipal;

  const mockRequest: AuthorizedRequest = {
    authorizationPrincipal: principal,
  } as unknown as AuthorizedRequest;

  const sampleOrder: PaymentOrderContract = {
    id: 'ord-123',
    bookingId: 'book-123',
    amountMinor: 50000,
    currency: 'INR',
    status: 'CREATED',
    gatewayOrderId: 'order_gw_123',
    createdAt: new Date().toISOString(),
  };

  beforeEach(() => {
    service = {
      createForBooking: jest.fn(),
      getForBooking: jest.fn(),
      getInvoice: jest.fn(),
      verifyCheckout: jest.fn(),
      processWebhook: jest.fn(),
    } as unknown as jest.Mocked<PaymentsService>;

    controller = new PaymentsController(service);
  });

  describe('createOrder', () => {
    it('calls service.createForBooking with principal and bookingId', async () => {
      const mockOrder = { ...sampleOrder };
      service.createForBooking.mockResolvedValue(mockOrder);

      const result = await controller.createOrder(mockRequest, {
        bookingId: 'book-123',
      });

      expect(service.createForBooking).toHaveBeenCalledWith(
        'user-cust-1',
        'book-123',
        principal,
      );
      expect(result).toBe(mockOrder);
    });
  });

  describe('getForBooking', () => {
    it('retrieves order bound to bookingId', async () => {
      const mockOrder = { ...sampleOrder };
      service.getForBooking.mockResolvedValue(mockOrder);

      const result = await controller.getForBooking('book-123', mockRequest);

      expect(service.getForBooking).toHaveBeenCalledWith(
        'user-cust-1',
        'book-123',
        principal,
      );
      expect(result).toBe(mockOrder);
    });
  });

  describe('invoice', () => {
    it('retrieves tax invoice for completed order', async () => {
      const mockInvoice = {
        invoiceNumber: 'INV-001',
        issuedAt: new Date().toISOString(),
        amountMinor: 50000,
        currency: 'INR',
        status: 'PAID',
      };
      service.getInvoice.mockResolvedValue(mockInvoice);

      const result = await controller.invoice('ord-123', mockRequest);

      expect(service.getInvoice).toHaveBeenCalledWith(
        'user-cust-1',
        'ord-123',
        principal,
      );
      expect(result).toBe(mockInvoice);
    });
  });

  describe('verifyCheckout', () => {
    it('verifies razorpay signature parameters', async () => {
      const mockVerified: PaymentOrderContract = {
        ...sampleOrder,
        status: 'PAID',
      };
      service.verifyCheckout.mockResolvedValue(mockVerified);

      const result = await controller.verifyCheckout(mockRequest, {
        orderId: 'ord-123',
        razorpayPaymentId: 'pay_xyz',
        razorpaySignature: 'sig_abc',
      });

      expect(service.verifyCheckout).toHaveBeenCalledWith(
        'user-cust-1',
        'ord-123',
        { gatewayPaymentId: 'pay_xyz', signature: 'sig_abc' },
        principal,
      );
      expect(result).toBe(mockVerified);
    });
  });

  describe('webhook', () => {
    it('processes raw webhook body and signature', async () => {
      const rawBody = Buffer.from(
        JSON.stringify({ event: 'payment.captured' }),
      );
      const webhookReq = {
        rawBody,
        headers: { 'x-razorpay-signature': 'sig-webhook-123' },
      } as unknown as AuthorizedRequest & { rawBody?: Buffer };

      service.processWebhook.mockResolvedValue({ handled: true });

      const result = await controller.webhook(webhookReq);

      expect(service.processWebhook).toHaveBeenCalledWith(
        rawBody,
        'sig-webhook-123',
      );
      expect(result).toEqual({ handled: true });
    });

    it('throws BadRequestException when rawBody is missing or not a Buffer', async () => {
      const invalidReq = { headers: {} } as unknown as AuthorizedRequest & {
        rawBody?: Buffer;
      };

      await expect(controller.webhook(invalidReq)).rejects.toThrow(
        BadRequestException,
      );
    });
  });
});
