import {
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
  const dataSource = {
    getRepository: jest.fn((entity: unknown) =>
      entity === Booking
        ? bookingRepo
        : entity === ServiceCategoryEntity
          ? categoryRepo
          : eventRepo,
    ),
  };
  const orders = {
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

  const ownedBooking = (status = BookingStatus.REQUESTED) =>
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
    orders.update.mockResolvedValue({ affected: 1 });
    bookingRepo.findOneBy.mockResolvedValue(ownedBooking());
    categoryRepo.findOneBy.mockResolvedValue(pricedCategory());
    orders.findOneBy.mockResolvedValue(null);
  });

  describe('createForBooking', () => {
    it('creates one CREATED order from the published category price', async () => {
      const order = await service.createForBooking(customerId, bookingId);
      expect(order.status).toBe(PaymentOrderStatus.CREATED);
      expect(order.amountMinor).toBe(49900);
      expect(gateway.orders).toHaveLength(1);
      expect(eventRepo.insert).toHaveBeenCalled();
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
