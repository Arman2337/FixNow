import { BadRequestException } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

describe('PaymentsController', () => {
  let controller: PaymentsController;
  let service: jest.Mocked<PaymentsService>;

  const principal = {
    userId: 'user-cust-1',
    role: 'customer',
  } as any;

  const mockRequest = {
    authorizationPrincipal: principal,
  } as any;

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
      const mockOrder = { orderId: 'ord-123', status: 'CREATED' } as any;
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
      const mockOrder = { orderId: 'ord-123' } as any;
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
        totalMinor: 50000,
      } as any;
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
      const mockVerified = { orderId: 'ord-123', status: 'PAID' } as any;
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
      } as any;

      service.processWebhook.mockResolvedValue({ handled: true });

      const result = await controller.webhook(webhookReq);

      expect(service.processWebhook).toHaveBeenCalledWith(
        rawBody,
        'sig-webhook-123',
      );
      expect(result).toEqual({ handled: true });
    });

    it('throws BadRequestException when rawBody is missing or not a Buffer', async () => {
      const invalidReq = { headers: {} } as any;

      await expect(controller.webhook(invalidReq)).rejects.toThrow(
        BadRequestException,
      );
    });
  });
});
