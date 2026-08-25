import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { createHash } from 'crypto';
import { DataSource, QueryFailedError, Repository } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type { PaymentOrderContract } from '../../../shared/payments.types';
import { PAYMENT_GATEWAY, type PaymentGateway } from './payment-gateway';
import { Inject } from '@nestjs/common';
import {
  PaymentOrder,
  PaymentOrderStatus,
} from './domain/payment-order.entity';
import { PaymentEvent } from './domain/payment-event.entity';
import { Refund } from './domain/refund.entity';
import { Invoice } from './domain/invoice.entity';
import type {
  CreatePaymentOrderRequest,
  VerifyCheckoutParams,
} from '../../../shared/payments.types';
import { TrustService } from '../trust/trust.service';

/** Booking states for which the customer may open a payment. */
const PAYABLE_BOOKING_STATUSES: readonly string[] = [
  BookingStatus.REQUESTED,
  BookingStatus.ASSIGNED,
];

@Injectable()
export class PaymentsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    @InjectRepository(PaymentOrder)
    private readonly orders: Repository<PaymentOrder>,
    @Inject(PAYMENT_GATEWAY) private readonly gateway: PaymentGateway,
    private readonly trust?: TrustService,
  ) {}

  /**
   * FN-052: create (or idempotently return) the booking-bound payment order.
   * The amount is the category's published price at order time; bookings in
   * "price on request" categories cannot be paid yet.
   */
  async createForBooking(
    customerId: string,
    bookingId: string,
  ): Promise<PaymentOrderContract> {
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!booking || booking.customerId !== customerId) {
      throw new NotFoundException('Booking not found');
    }
    if (!PAYABLE_BOOKING_STATUSES.includes(booking.status)) {
      throw new ConflictException(
        'This booking can no longer accept a new payment',
      );
    }
    const receipt = `booking:${booking.id}`;
    const existing = await this.orders.findOneBy({ receipt });
    if (existing) return this.present(existing);

    const category = await this.dataSource
      .getRepository(ServiceCategoryEntity)
      .findOneBy({ id: booking.serviceCategoryId });
    // Only the approved currency is payable; anything else is treated as
    // "price on request" rather than guessed.
    const currency =
      category?.priceCurrency === 'INR' ? category.priceCurrency : null;
    if (!category?.priceAmount || !currency) {
      throw new ConflictException(
        'This service is priced on request; online payment is unavailable',
      );
    }
    const input: CreatePaymentOrderRequest = {
      amountMinor: category.priceAmount,
      currency,
      receipt,
      notes: { bookingId: booking.id },
    };
    const gatewayOrder = await this.gateway.createOrder(input);
    try {
      const saved = await this.orders.save(
        this.orders.create({
          bookingId: booking.id,
          customerId,
          amountMinor: gatewayOrder.amountMinor,
          currency: gatewayOrder.currency,
          status: PaymentOrderStatus.CREATED,
          gatewayOrderId: gatewayOrder.gatewayOrderId,
          receipt,
        }),
      );
      await this.appendEvent(
        saved.id,
        'order.created',
        'system',
        createHash('sha256').update(receipt).digest('hex'),
      );
      return this.present(saved);
    } catch (error: unknown) {
      if (this.isUniqueViolation(error)) {
        const raced = await this.orders.findOneByOrFail({ receipt });
        return this.present(raced);
      }
      throw error;
    }
  }

  /** Customer-side Checkout handshake verification (webhook stays authoritative). */
  async verifyCheckout(
    customerId: string,
    orderId: string,
    params: Omit<VerifyCheckoutParams, 'gatewayOrderId'>,
  ): Promise<PaymentOrderContract> {
    const order = await this.ownedOrder(customerId, orderId);
    if (order.status !== PaymentOrderStatus.CREATED) {
      throw new ConflictException('This payment was already finalised');
    }
    const valid = this.gateway.verifyCheckoutSignature({
      gatewayOrderId: order.gatewayOrderId,
      gatewayPaymentId: params.gatewayPaymentId,
      signature: params.signature,
    });
    if (!valid) {
      throw new ForbiddenException('Payment signature verification failed');
    }
    return this.markPaid(order, params.gatewayPaymentId, 'customer');
  }

  /**
   * Webhook processing. The raw body is HMAC-verified BEFORE parsing; replays
   * are dropped by the payment_events unique index; captured amounts must
   * match the internal order exactly.
   */
  async processWebhook(
    rawBody: Buffer | string | undefined,
    signature: string | undefined,
  ): Promise<{ handled: boolean; duplicate?: boolean }> {
    if (!rawBody || !signature) {
      throw new BadRequestException('Missing webhook payload or signature');
    }
    const bodyText = Buffer.isBuffer(rawBody)
      ? rawBody.toString('utf8')
      : rawBody;
    if (!this.gateway.verifyWebhookSignature(bodyText, signature)) {
      throw new ForbiddenException('Webhook signature verification failed');
    }
    let parsed: {
      event?: string;
      payload?: { payment?: { entity?: Record<string, unknown> } };
    };
    try {
      parsed = JSON.parse(bodyText) as typeof parsed;
    } catch {
      throw new BadRequestException('Webhook payload is not valid JSON');
    }
    const entity = parsed.payload?.payment?.entity;
    const eventType = parsed.event ?? '';
    const gatewayPaymentId =
      typeof entity?.id === 'string' ? entity.id : undefined;
    const gatewayOrderId =
      typeof entity?.order_id === 'string' ? entity.order_id : undefined;
    if (!eventType || !gatewayOrderId) {
      return { handled: false }; // Not a payment event we track; acknowledge.
    }
    const order = await this.orders.findOneBy({
      gatewayOrderId,
    });
    if (!order) return { handled: false };

    const digest = createHash('sha256').update(bodyText).digest('hex');
    const replay = await this.dataSource
      .getRepository(PaymentEvent)
      .findOneBy({ orderId: order.id, eventType, payloadDigest: digest });
    if (replay) return { handled: true, duplicate: true };

    if (eventType === 'payment.captured') {
      const capturedAmount =
        typeof entity?.amount === 'number' ? entity.amount : -1;
      if (capturedAmount !== order.amountMinor) {
        // Amount tampering: never accept; record and leave the order untouched.
        await this.appendEvent(
          order.id,
          'payment.captured.amount_mismatch',
          'webhook',
          digest,
        );
        return { handled: true };
      }
      await this.markPaid(order, gatewayPaymentId ?? null, 'webhook');
      await this.appendEvent(order.id, eventType, 'webhook', digest);
      return { handled: true };
    }
    if (eventType === 'payment.failed') {
      const advanced = await this.orders.update(
        { id: order.id, status: PaymentOrderStatus.CREATED },
        {
          status: PaymentOrderStatus.FAILED,
          failureReason: 'The payment attempt failed at the gateway',
        },
      );
      if (advanced.affected) {
        await this.appendEvent(order.id, eventType, 'webhook', digest);
      }
      return { handled: true };
    }
    return { handled: false };
  }

  async getForBooking(
    customerId: string,
    bookingId: string,
  ): Promise<PaymentOrderContract | null> {
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!booking || booking.customerId !== customerId) {
      throw new NotFoundException('Booking not found');
    }
    const order = await this.orders.findOneBy({
      receipt: `booking:${bookingId}`,
    });
    return order ? this.present(order) : null;
  }

  /** Race-safe PAID transition: only CREATED orders may advance. */
  private async markPaid(
    order: PaymentOrder,
    gatewayPaymentId: string | null,
    actor: string,
  ): Promise<PaymentOrderContract> {
    const advanced = await this.orders.update(
      { id: order.id, status: PaymentOrderStatus.CREATED },
      { status: PaymentOrderStatus.PAID, gatewayPaymentId },
    );
    if (!advanced.affected) {
      const raced = await this.orders.findOneByOrFail({ id: order.id });
      if (raced.status !== PaymentOrderStatus.PAID) {
        throw new ConflictException('This payment was already finalised');
      }
      return this.present(raced);
    }
    await this.appendEvent(
      order.id,
      'payment.verified',
      actor,
      createHash('sha256')
        .update(`${order.gatewayOrderId}|${gatewayPaymentId ?? ''}`)
        .digest('hex'),
    );
    await this.ensureInvoice(order.id);
    return this.present({
      ...order,
      status: PaymentOrderStatus.PAID,
      gatewayPaymentId,
    });
  }

  /**
   * FN-053: exactly one invoice per paid order. The number comes from a
   * database sequence, so concurrent PAID transitions can never collide.
   */
  private async ensureInvoice(orderId: string): Promise<void> {
    const invoices = this.dataSource.getRepository(Invoice);
    const existing = await invoices.findOneBy({ paymentOrderId: orderId });
    if (existing) return;
    const issuedAt = new Date();
    const rows = await this.dataSource.query<Array<{ nextval?: string }>>(
      `SELECT nextval('invoice_number_seq') AS nextval`,
    );
    const invoiceNumber = `FN-${issuedAt.getUTCFullYear()}-${(
      rows[0]?.nextval ?? '0'
    ).padStart(6, '0')}`;
    try {
      await invoices.insert(
        invoices.create({ paymentOrderId: orderId, invoiceNumber, issuedAt }),
      );
    } catch (error: unknown) {
      if (!this.isUniqueViolation(error)) throw error;
      // A concurrent finalisation of the same order won the invoice race.
    }
  }

  /** Customer-visible invoice for an own paid order. */
  async getInvoice(
    customerId: string,
    orderId: string,
  ): Promise<{
    invoiceNumber: string;
    issuedAt: string;
    amountMinor: number;
    currency: string;
    status: string;
  }> {
    const order = await this.ownedOrder(customerId, orderId);
    if (order.status !== PaymentOrderStatus.PAID) {
      throw new ConflictException('Invoices exist only for paid payments');
    }
    const invoice = await this.dataSource
      .getRepository(Invoice)
      .findOneByOrFail({ paymentOrderId: order.id });
    return {
      invoiceNumber: invoice.invoiceNumber,
      issuedAt: invoice.issuedAt.toISOString(),
      amountMinor: order.amountMinor,
      currency: order.currency,
      status: order.status,
    };
  }

  /**
   * FN-053: controlled refunds against a PAID order. Partial refunds are
   * allowed; the lifetime refund total can never exceed the paid amount.
   * Idempotent per caller-supplied request key.
   */
  async refundOrder(
    actorId: string,
    orderId: string,
    input: { amountMinor?: number; reason: string; requestKey?: string },
  ): Promise<{
    id: string;
    gatewayRefundId: string;
    amountMinor: number;
    status: string;
  }> {
    if (input.requestKey) {
      const existing = await this.dataSource
        .getRepository(Refund)
        .findOneBy({ requestKey: input.requestKey });
      if (existing) {
        return {
          id: existing.id,
          gatewayRefundId: existing.gatewayRefundId,
          amountMinor: existing.amountMinor,
          status: existing.status,
        };
      }
    }
    const order = await this.orders.findOneByOrFail({ id: orderId });
    if (order.status !== PaymentOrderStatus.PAID || !order.gatewayPaymentId) {
      throw new ConflictException('Only paid payments can be refunded');
    }
    if (!input.reason.trim() || input.reason.length > 200) {
      throw new BadRequestException('A bounded refund reason is required');
    }
    const alreadyRefunded = await this.refundedTotal(order.id);
    const amountMinor = input.amountMinor ?? order.amountMinor;
    if (
      !Number.isInteger(amountMinor) ||
      amountMinor <= 0 ||
      alreadyRefunded + amountMinor > order.amountMinor
    ) {
      throw new ConflictException(
        'Refund exceeds the refundable balance for this payment',
      );
    }
    const gatewayRefund = await this.gateway.createRefund({
      gatewayPaymentId: order.gatewayPaymentId,
      amountMinor,
      requestKey: input.requestKey,
    });
    try {
      const saved = await this.dataSource.getRepository(Refund).save(
        this.dataSource.getRepository(Refund).create({
          paymentOrderId: order.id,
          gatewayRefundId: gatewayRefund.gatewayRefundId,
          requestKey: input.requestKey ?? null,
          amountMinor,
          currency: order.currency,
          status: 'PROCESSED',
          reason: input.reason.trim(),
          createdBy: actorId,
        }),
      );
      await this.appendEvent(
        order.id,
        'refund.created',
        actorId,
        createHash('sha256')
          .update(gatewayRefund.gatewayRefundId)
          .digest('hex'),
      );
      // FN-060: refund-frequency review signal is best-effort; it can never
      // fail a recorded refund.
      try {
        const booking = await this.dataSource
          .getRepository(Booking)
          .findOneBy({ id: order.bookingId });
        if (booking?.providerId) {
          await this.trust?.evaluateProviderRefundSignal(booking.providerId);
        }
      } catch {
        // Signal evaluation failures are non-fatal by design.
      }
      return {
        id: saved.id,
        gatewayRefundId: saved.gatewayRefundId,
        amountMinor: saved.amountMinor,
        status: saved.status,
      };
    } catch (error: unknown) {
      if (this.isUniqueViolation(error)) {
        // Lost the idempotency race; the first refund stands.
        const raced = await this.dataSource
          .getRepository(Refund)
          .findOneByOrFail({ gatewayRefundId: gatewayRefund.gatewayRefundId });
        return {
          id: raced.id,
          gatewayRefundId: raced.gatewayRefundId,
          amountMinor: raced.amountMinor,
          status: raced.status,
        };
      }
      throw error;
    }
  }

  private async refundedTotal(paymentOrderId: string): Promise<number> {
    const rows = await this.dataSource.query<Array<{ total?: string }>>(
      `SELECT COALESCE(SUM(amount_minor), 0) AS total FROM refunds WHERE payment_order_id = $1`,
      [paymentOrderId],
    );
    return parseInt(rows[0]?.total ?? '0', 10);
  }

  /**
   * FN-053: honest provider earnings ledger derived from paid orders minus
   * refunds. This records money flows; it does NOT represent payouts, which
   * no provider supports yet (ADR-0016).
   */
  async providerEarnings(providerId: string): Promise<{
    grossMinor: number;
    refundedMinor: number;
    netMinor: number;
    paidOrderCount: number;
    note: string;
  }> {
    const grossRows = await this.dataSource.query<
      Array<{ gross?: string; count?: number }>
    >(
      `SELECT COALESCE(SUM(o.amount_minor), 0) AS gross, COUNT(*)::int AS count
       FROM payment_orders o
       JOIN bookings b ON b.id = o.booking_id
       WHERE b.provider_id = $1 AND o.status = 'PAID'`,
      [providerId],
    );
    const refundedRows = await this.dataSource.query<Array<{ total?: string }>>(
      `SELECT COALESCE(SUM(r.amount_minor), 0) AS total
       FROM refunds r
       JOIN payment_orders o ON o.id = r.payment_order_id
       JOIN bookings b ON b.id = o.booking_id
       WHERE b.provider_id = $1 AND o.status = 'PAID'`,
      [providerId],
    );
    const grossMinor = parseInt(grossRows[0]?.gross ?? '0', 10);
    const refundedMinor = parseInt(refundedRows[0]?.total ?? '0', 10);
    return {
      grossMinor,
      refundedMinor,
      netMinor: grossMinor - refundedMinor,
      paidOrderCount: grossRows[0]?.count ?? 0,
      note: 'Records of completed payments. Payouts are not available yet.',
    };
  }

  private async appendEvent(
    orderId: string,
    eventType: string,
    actor: string,
    payloadDigest: string,
  ): Promise<void> {
    try {
      await this.dataSource.getRepository(PaymentEvent).insert(
        this.dataSource.getRepository(PaymentEvent).create({
          orderId,
          eventType,
          actor,
          payloadDigest,
        }),
      );
    } catch (error: unknown) {
      if (this.isUniqueViolation(error)) {
        return; // Replay lost the race; idempotent by design.
      }
      throw error;
    }
  }

  private async ownedOrder(
    customerId: string,
    orderId: string,
  ): Promise<PaymentOrder> {
    const order = await this.orders.findOneBy({ id: orderId, customerId });
    if (!order) throw new NotFoundException('Payment order not found');
    return order;
  }

  private isUniqueViolation(error: unknown): boolean {
    return (
      error instanceof QueryFailedError &&
      (error.driverError as { code?: unknown }).code === '23505'
    );
  }

  private present(order: PaymentOrder): PaymentOrderContract {
    return {
      id: order.id,
      bookingId: order.bookingId,
      amountMinor: order.amountMinor,
      currency: order.currency,
      status: order.status,
      gatewayOrderId: order.gatewayOrderId,
      createdAt: order.createdAt.toISOString(),
    };
  }
}
