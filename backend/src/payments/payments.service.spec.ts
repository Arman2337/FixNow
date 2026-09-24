import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { QueryFailedError } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { FakePaymentGateway } from './payment-gateway';
import {
  PaymentOrder,
  PaymentOrderStatus,
} from './domain/payment-order.entity';
import { Invoice } from './domain/invoice.entity';
import { Refund } from './domain/refund.entity';
import { PaymentEvent } from './domain/payment-event.entity';
import { PaymentsService } from './payments.service';

const uniqueError = () =>
  ({ driverError: { code: '23505' } }) as unknown as QueryFailedError;

describe('PaymentsService', () => {
  const customerId = '00000000-0000-4000-8000-00000000c001';
  const otherUserId = '00000000-0000-4000-8000-00000000c002';
  const bookingId = 'bbbbbbbb-0000-4000-8000-00000000b001';
  const categoryId = 'cccccccc-0000-4000-8000-00000000c003';

  const bookingRepo = { findOneBy: jest.fn() };
  const categoryRepo = { findOneBy: jest.fn() };
  const eventRepo = {
    findOneBy: jest.fn().mockResolvedValue(null),
    insert: jest.fn().mockResolvedValue(undefined),
    create: jest.fn(<T extends object>(value: T): T => value),
  };
  const invoiceRepo = {
    findOneBy: jest.fn().mockResolvedValue(null),
    findOneByOrFail: jest.fn().mockResolvedValue({
      invoiceNumber: 'FN-2026-000001',
      issuedAt: new Date('2026-08-25T00:00:00Z'),
    }),
    insert: jest.fn().mockResolvedValue(undefined),
    create: jest.fn(<T extends object>(value: T): T => value),
  };
  let refundStore: Record<string, unknown> | null = null;
  const refundRepo = {
    findOneBy: jest.fn().mockResolvedValue(null),
    findOneByOrFail: jest.fn(),
    save: jest.fn((value) =>
      Promise.resolve({ id: 'refund-1', status: 'PROCESSED', ...value }),
    ),
    update: jest.fn().mockResolvedValue({ affected: 1 }),
    create: jest.fn(<T extends object>(value: T): T => value),
  };
  let dataSource: {
    getRepository: jest.Mock;
    query: jest.Mock;
    transaction: jest.Mock;
  };
  const transactionManager = {
    getRepository: jest.fn((entity: unknown) =>
      entity === PaymentOrder
        ? orders
        : entity === Refund
          ? refundRepo
          : entity === PaymentEvent
            ? eventRepo
            : entity === Booking
              ? bookingRepo
              : entity === ServiceCategoryEntity
                ? categoryRepo
                : entity === Invoice
                  ? invoiceRepo
                  : eventRepo,
    ),
    query: jest.fn((...args: unknown[]) => dataSource.query(...args)),
  };
  dataSource = {
    getRepository: jest.fn((entity: unknown) =>
      entity === Booking
        ? bookingRepo
        : entity === ServiceCategoryEntity
          ? categoryRepo
          : entity === Invoice
            ? invoiceRepo
            : entity === Refund
              ? refundRepo
              : eventRepo,
    ),
    query: jest.fn(),
    transaction: jest.fn(
      async (_isolation: string, callback: (manager: typeof transactionManager) => unknown) =>
        callback(transactionManager),
    ),
  };
  const orders = {
    findOne: jest.fn(),
    findOneBy: jest.fn().mockResolvedValue(null),
    findOneByOrFail: jest.fn(),
    save: jest.fn((value) =>
      Promise.resolve({
        createdAt: new Date(),
        ...value,
      }),
    ),
    create: jest.fn(<T extends object>(value: T): T => value),
    update: jest.fn().mockResolvedValue({ affected: 1 }),
  };
  let gateway = new FakePaymentGateway();
  let service: PaymentsService;
  const buildService = () => {
    gateway = new FakePaymentGateway();
    service = new PaymentsService(
      dataSource as never,
      orders as never,
      gateway,
    );
  };

  const ownedBooking = (status = BookingStatus.COMPLETED) =>
    ({
      id: bookingId,
      customerId,
      providerId: null,
      serviceCategoryId: categoryId,
      status,
    }) as Booking;

  const pricedCategory = () =>
    ({
      id: categoryId,
      priceAmount: 49900,
      priceCurrency: 'INR',
    }) as ServiceCategoryEntity;

  const savedOrder = (overrides: Record<string, unknown> = {}) =>
    ({
      id: 'oooooooo-0000-4000-8000-00000000o001',
      bookingId,
      customerId,
      amountMinor: 49900,
      currency: 'INR',
      status: PaymentOrderStatus.CREATED,
      gatewayOrderId: 'order_fake_00000000000001',
      receipt: `booking:${bookingId}`,
      gatewayPaymentId: null,
      createdAt: new Date(),
      ...overrides,
    }) as PaymentOrder;

  beforeEach(() => {
    buildService();
    jest.clearAllMocks();
    eventRepo.findOneBy.mockResolvedValue(null);
    eventRepo.insert.mockResolvedValue(undefined);
    invoiceRepo.findOneBy.mockResolvedValue(null);
    refundStore = null;
    refundRepo.findOneBy.mockImplementation((criteria: { requestKey?: string }) => {
      if (!refundStore || refundStore.requestKey !== criteria.requestKey) {
        return Promise.resolve(null);
      }
      return Promise.resolve(refundStore);
    });
    refundRepo.save.mockReset();
    refundRepo.save.mockImplementation((value: Record<string, unknown>) => {
      refundStore = { id: 'refund-1', ...value };
      return Promise.resolve(refundStore);
    });
    orders.update.mockResolvedValue({ affected: 1 });
    orders.findOne.mockResolvedValue(
      savedOrder({
        status: PaymentOrderStatus.PAID,
        gatewayPaymentId: 'pay_5',
      }),
    );
    bookingRepo.findOneBy.mockResolvedValue(ownedBooking());
    categoryRepo.findOneBy.mockResolvedValue(pricedCategory());
    orders.findOneBy.mockResolvedValue(null);
    orders.save.mockReset();
    orders.save.mockImplementation((value: Record<string, unknown>) =>
      Promise.resolve({
        id: 'oooooooo-0000-4000-8000-00000000o001',
        createdAt: new Date(),
        ...value,
      }),
    );
    dataSource.query.mockImplementation((sql: string) => {
      if (sql.includes('SUM(o.amount_minor)')) {
        return Promise.resolve([{ gross: '49900', count: 1 }]);
      }
      if (sql.includes('FROM refunds')) {
        return Promise.resolve([{ total: '0' }]);
      }
      return Promise.resolve([{ total: '9900' }]);
    });
  });

  describe('providerBookingPaymentStatus', () => {
    it('reports paid only for a PAID order on the provider-assigned booking', async () => {
      buildService();
      dataSource.query.mockResolvedValue([{ status: 'PAID' }]);
      await expect(
        service.providerBookingPaymentStatus(otherUserId, bookingId),
      ).resolves.toEqual({ bookingId, paid: true });
      expect(dataSource.query).toHaveBeenCalledWith(
        expect.stringContaining('b.provider_id = $2'),
        [bookingId, otherUserId],
      );
    });

    it('reports unpaid when there is no order or it is not PAID', async () => {
      buildService();
      dataSource.query.mockResolvedValue([]);
      await expect(
        service.providerBookingPaymentStatus(otherUserId, bookingId),
      ).resolves.toEqual({ bookingId, paid: false });

      dataSource.query.mockResolvedValue([{ status: 'CREATED' }]);
      await expect(
        service.providerBookingPaymentStatus(otherUserId, bookingId),
      ).resolves.toEqual({ bookingId, paid: false });
    });
  });

  describe('createForBooking', () => {
    it('creates one CREATED order from the published category price', async () => {
      const order = await service.createForBooking(customerId, bookingId);
      expect(order.status).toBe(PaymentOrderStatus.CREATED);
      expect(order.amountMinor).toBe(49900);
      expect(gateway.orders).toHaveLength(1);
      expect(eventRepo.insert).toHaveBeenCalled();
    });

    it('uses the line-item total without adding the category price again', async () => {
      const booking = ownedBooking();
      categoryRepo.findOneBy.mockResolvedValue({
        id: categoryId,
        priceAmount: 14900,
        priceCurrency: 'INR',
      });
      booking.lineItems = [
        { priceMinor: 14900, quantity: 1 },
        { priceMinor: 10000, quantity: 1 },
      ] as never;
      booking.totalAmountMinor = 24900;
      bookingRepo.findOneBy.mockResolvedValue(booking);

      const order = await service.createForBooking(customerId, bookingId);

      expect(order.amountMinor).toBe(24900);
      expect(gateway.orders[0]?.amountMinor).toBe(24900);
    });

    it('returns the existing order on replay without touching the gateway', async () => {
      orders.findOneBy.mockResolvedValue(savedOrder());
      const order = await service.createForBooking(customerId, bookingId);
      expect(order.gatewayOrderId).toBe('order_fake_00000000000001');
      expect(gateway.orders).toHaveLength(0);
    });

    it('returns the raced order when the receipt unique constraint fires', async () => {
      orders.save.mockRejectedValueOnce(uniqueError());
      orders.findOneBy.mockResolvedValueOnce(savedOrder());
      const order = await service.createForBooking(customerId, bookingId);
      expect(order.gatewayOrderId).toBe('order_fake_00000000000001');
    });

    it('refuses another customer’s booking', async () => {
      await expect(
        service.createForBooking(otherUserId, bookingId),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('refuses terminal bookings', async () => {
      bookingRepo.findOneBy.mockResolvedValue(
        ownedBooking(BookingStatus.CANCELLED),
      );
      await expect(
        service.createForBooking(customerId, bookingId),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('accepts COMPLETED bookings for post-service payment', async () => {
      bookingRepo.findOneBy.mockResolvedValue(
        ownedBooking(BookingStatus.COMPLETED),
      );
      const order = await service.createForBooking(customerId, bookingId);
      expect(order.status).toBe(PaymentOrderStatus.CREATED);
      expect(order.amountMinor).toBe(49900);
    });

    it('refuses price-on-request categories instead of inventing an amount', async () => {
      categoryRepo.findOneBy.mockResolvedValue({
        id: categoryId,
        priceAmount: null,
        priceCurrency: null,
      });
      await expect(
        service.createForBooking(customerId, bookingId),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(gateway.orders).toHaveLength(0);
    });
  });

  describe('verifyCheckout', () => {
    it('marks PAID on a valid fake handshake and records the event', async () => {
      const order = savedOrder();
      orders.findOneBy.mockResolvedValue(order);
      const result = await service.verifyCheckout(customerId, order.id, {
        gatewayPaymentId: 'pay_1',
        signature: `fake-${order.gatewayOrderId}:pay_1`,
      });
      expect(result.status).toBe(PaymentOrderStatus.PAID);
      expect(orders.update).toHaveBeenCalledWith(
        expect.objectContaining({ id: order.id, status: 'CREATED' }),
        expect.objectContaining({ status: 'PAID', gatewayPaymentId: 'pay_1' }),
      );
    });

    it('rejects a forged signature without changing state', async () => {
      orders.findOneBy.mockResolvedValue(savedOrder());
      await expect(
        service.verifyCheckout(customerId, savedOrder().id, {
          gatewayPaymentId: 'pay_1',
          signature: 'forged',
        }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(orders.update).not.toHaveBeenCalled();
    });

    it('refuses to finalise an already-paid order', async () => {
      orders.findOneBy.mockResolvedValue(
        savedOrder({ status: PaymentOrderStatus.PAID }),
      );
      await expect(
        service.verifyCheckout(customerId, savedOrder().id, {
          gatewayPaymentId: 'pay_1',
          signature: 'x',
        }),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('processWebhook', () => {
    // The fake gateway's marker scheme is `fake-<bodyLength>`.
    const sign = (body: string) => `fake-${body.length}`;

    const capturedBody = (orderId: string, amount = 49900) =>
      JSON.stringify({
        event: 'payment.captured',
        payload: {
          payment: {
            entity: { id: 'pay_9', order_id: orderId, amount },
          },
        },
      });

    it('rejects an invalid signature before parsing anything', async () => {
      await expect(
        service.processWebhook('{}', 'bad-signature'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(orders.update).not.toHaveBeenCalled();
    });

    it('marks the order PAID on a valid captured event', async () => {
      const order = savedOrder();
      orders.findOneBy.mockResolvedValue(order);
      const body = capturedBody(order.gatewayOrderId);
      const result = await service.processWebhook(body, sign(body));
      expect(result.handled).toBe(true);
      expect(orders.update).toHaveBeenCalledWith(
        expect.objectContaining({ id: order.id, status: 'CREATED' }),
        expect.objectContaining({
          status: 'PAID',
          gatewayPaymentId: 'pay_9',
        }),
      );
    });

    it('never accepts a captured amount that differs from the order', async () => {
      const order = savedOrder();
      orders.findOneBy.mockResolvedValue(order);
      const body = capturedBody(order.gatewayOrderId, 100); // tampered
      await service.processWebhook(body, sign(body));
      expect(orders.update).not.toHaveBeenCalled();
      expect(eventRepo.insert).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: 'payment.captured.amount_mismatch',
        }),
      );
    });

    it('drops webhook replays through the event digest', async () => {
      const order = savedOrder();
      orders.findOneBy.mockResolvedValue(order);
      eventRepo.findOneBy.mockResolvedValue({ id: 'already-processed' });
      const body = capturedBody(order.gatewayOrderId);
      const result = await service.processWebhook(body, sign(body));
      expect(result).toEqual({ handled: true, duplicate: true });
      expect(orders.update).not.toHaveBeenCalled();
    });

    it('marks the order FAILED on a failed payment event', async () => {
      const order = savedOrder();
      orders.findOneBy.mockResolvedValue(order);
      const body = JSON.stringify({
        event: 'payment.failed',
        payload: {
          payment: {
            entity: {
              id: 'pay_9',
              order_id: order.gatewayOrderId,
              amount: 49900,
            },
          },
        },
      });
      await service.processWebhook(body, sign(body));
      expect(orders.update).toHaveBeenCalledWith(
        expect.objectContaining({ id: order.id, status: 'CREATED' }),
        expect.objectContaining({ status: 'FAILED' }),
      );
    });

    it('acknowledges events for unknown orders without action', async () => {
      orders.findOneBy.mockResolvedValue(null);
      const body = capturedBody('order_unknown');
      const result = await service.processWebhook(body, sign(body));
      expect(result).toEqual({ handled: false });
    });
  });

  describe('providerEarnings', () => {
    it('nets paid orders minus refunds and states the no-payout note', async () => {
      dataSource.query
        .mockResolvedValueOnce([{ gross: '49900', count: 1 }])
        .mockResolvedValueOnce([{ total: '9900' }]);
      const result = await service.providerEarnings(otherUserId);
      expect(result).toEqual({
        grossMinor: 49900,
        refundedMinor: 9900,
        netMinor: 40000,
        paidOrderCount: 1,
        note: 'Records of completed payments. Payouts are not available yet.',
      });
    });
  });

  describe('refundOrder', () => {
    const paidOrder = () =>
      savedOrder({
        status: PaymentOrderStatus.PAID,
        gatewayPaymentId: 'pay_5',
      });

    it('requires an idempotency key before contacting the gateway', async () => {
      orders.findOneByOrFail.mockResolvedValue(paidOrder());

      await expect(
        service.refundOrder('staff-1', savedOrder().id, {
          reason: 'missing idempotency key',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(dataSource.transaction).not.toHaveBeenCalled();
      expect(gateway.refunds).toHaveLength(0);
    });

    it('reserves a refund under a serializable order lock before calling the gateway', async () => {
      orders.findOneByOrFail.mockResolvedValue(paidOrder());

      await service.refundOrder('staff-1', savedOrder().id, {
        amountMinor: 10000,
        reason: 'locked partial refund',
        requestKey: 'refund-lock-001',
      });

      expect(dataSource.transaction).toHaveBeenCalledWith(
        'SERIALIZABLE',
        expect.any(Function),
      );
      expect(orders.findOneByOrFail).not.toHaveBeenCalled();
      expect(refundRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          paymentOrderId: savedOrder().id,
          status: 'PENDING',
          requestKey: 'refund-lock-001',
        }),
      );
      expect(refundRepo.update).toHaveBeenCalledWith(
        expect.objectContaining({ requestKey: 'refund-lock-001' }),
        expect.objectContaining({ status: 'PROCESSED' }),
      );
    });

    it('issues a full refund against a paid order', async () => {
      orders.findOneByOrFail.mockResolvedValue(paidOrder());
      const refund = await service.refundOrder('staff-1', savedOrder().id, {
        reason: 'Service cancelled by support',
        requestKey: 'refund-key-001',
      });
      expect(refund.amountMinor).toBe(49900);
      expect(refund.gatewayRefundId).toMatch(/^rfnd_fake_/);
      expect(gateway.refunds).toHaveLength(1);
      expect(eventRepo.insert).toHaveBeenCalled();
    });

    it('supports partial refunds and rejects exceeding the balance', async () => {
      orders.findOneByOrFail.mockResolvedValue(paidOrder());
      const partial = await service.refundOrder('staff-1', savedOrder().id, {
        amountMinor: 10000,
        reason: 'Goodwill partial refund',
        requestKey: 'refund-key-002',
      });
      expect(partial.amountMinor).toBe(10000);

      dataSource.query.mockResolvedValue([{ total: '49900' }]);
      await expect(
        service.refundOrder('staff-1', savedOrder().id, {
          amountMinor: 1,
          reason: 'over the balance',
          requestKey: 'refund-key-003',
        }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('is idempotent per request key without a second gateway call', async () => {
      refundRepo.findOneBy.mockResolvedValue({
        id: 'refund-1',
        gatewayRefundId: 'rfnd_fake_existing',
        amountMinor: 49900,
        status: 'PROCESSED',
      });
      const refund = await service.refundOrder('staff-1', savedOrder().id, {
        reason: 'retry of the same request',
        requestKey: 'idem-key-001',
      });
      expect(refund.gatewayRefundId).toBe('rfnd_fake_existing');
      expect(refundRepo.findOneBy).toHaveBeenCalledWith({
        paymentOrderId: savedOrder().id,
        requestKey: 'idem-key-001',
      });
      expect(gateway.refunds).toHaveLength(0);
    });

    it('refuses refunds on unpaid orders', async () => {
      orders.findOne.mockResolvedValue(savedOrder()); // CREATED
      await expect(
        service.refundOrder('staff-1', savedOrder().id, {
          reason: 'too early',
          requestKey: 'refund-key-004',
        }),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('getForBooking', () => {
    it('returns null when no order exists yet', async () => {
      expect(await service.getForBooking(customerId, bookingId)).toBeNull();
    });
    it('refuses other customers’ bookings', async () => {
      await expect(
        service.getForBooking(otherUserId, bookingId),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
