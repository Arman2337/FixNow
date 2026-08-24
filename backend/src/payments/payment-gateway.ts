import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, timingSafeEqual } from 'crypto';
import type {
  CreatePaymentOrderRequest,
  PaymentGatewayOrder,
  VerifyCheckoutParams,
} from '../../../shared/payments.types';

export const PAYMENT_GATEWAY = Symbol('PAYMENT_GATEWAY');

/** Vendor-neutral payment boundary (ADR-0016). Implementations: fake, Razorpay. */
export interface PaymentGateway {
  createOrder(input: CreatePaymentOrderRequest): Promise<PaymentGatewayOrder>;
  /** Verifies the raw webhook body against X-Razorpay-Signature. */
  verifyWebhookSignature(rawBody: string, signature: string): boolean;
  /** Verifies the Checkout handshake (order_id|payment_id HMAC). */
  verifyCheckoutSignature(params: VerifyCheckoutParams): boolean;
}

export function assertSupportedPaymentAmount(
  amountMinor: number,
  currency: string,
): void {
  if (!Number.isInteger(amountMinor) || amountMinor <= 0) {
    throw new BadRequestException(
      'Payment amount must be a positive integer of paise',
    );
  }
  if (currency !== 'INR') {
    throw new BadRequestException('Only INR payments are supported');
  }
  if (amountMinor > 100_000_00) {
    // Mirrors the FN-107 category price ceiling (₹1,00,000 per order).
    throw new BadRequestException(
      'Payment amount exceeds the supported ceiling',
    );
  }
}

function safeEquals(expected: string, actual: string): boolean {
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(actual, 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}

/** Deterministic gateway for tests and local development. */
@Injectable()
export class FakePaymentGateway implements PaymentGateway {
  readonly orders: CreatePaymentOrderRequest[] = [];
  private sequence = 0;

  createOrder(input: CreatePaymentOrderRequest): Promise<PaymentGatewayOrder> {
    assertSupportedPaymentAmount(input.amountMinor, input.currency);
    this.orders.push(input);
    this.sequence += 1;
    return Promise.resolve({
      gatewayOrderId: `order_fake_${this.sequence.toString().padStart(14, '0')}`,
      amountMinor: input.amountMinor,
      currency: input.currency,
      status: 'created',
    });
  }

  verifyWebhookSignature(rawBody: string, signature: string): boolean {
    // The fake accepts only its own deterministic marker.
    return signature === `fake-${rawBody.length}`;
  }

  verifyCheckoutSignature(params: VerifyCheckoutParams): boolean {
    return (
      params.signature ===
      `fake-${params.gatewayOrderId}:${params.gatewayPaymentId}`
    );
  }
}

/** Thin Razorpay REST adapter — no SDK, basic auth, global fetch (ADR-0016). */
@Injectable()
export class RazorpayPaymentGateway implements PaymentGateway {
  private readonly config: ConfigService;

  constructor(config: ConfigService) {
    // Credentials resolve lazily: the module instantiates both providers, so
    // missing Razorpay env must not break fake-mode boots.
    this.config = config;
  }

  private credentials(): {
    keyId: string;
    keySecret: string;
    webhookSecret: string;
    baseUrl: string;
  } {
    const keyId = this.config.get<string>('RAZORPAY_KEY_ID') ?? '';
    const keySecret = this.config.get<string>('RAZORPAY_KEY_SECRET') ?? '';
    const webhookSecret =
      this.config.get<string>('RAZORPAY_WEBHOOK_SECRET') ?? '';
    const baseUrl =
      this.config.get<string>('RAZORPAY_BASE_URL') ??
      'https://api.razorpay.com/v1';
    if (!keyId || !keySecret || !webhookSecret) {
      throw new ServiceUnavailableException(
        'Payment gateway is not configured',
      );
    }
    return { keyId, keySecret, webhookSecret, baseUrl };
  }

  async createOrder(
    input: CreatePaymentOrderRequest,
  ): Promise<PaymentGatewayOrder> {
    assertSupportedPaymentAmount(input.amountMinor, input.currency);
    const { keyId, keySecret, baseUrl } = this.credentials();
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    const response = await fetch(`${baseUrl}/orders`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: input.amountMinor,
        currency: input.currency,
        receipt: input.receipt,
        notes: input.notes ?? {},
      }),
    });
    if (!response.ok) {
      throw new ServiceUnavailableException(
        'Payment gateway rejected the order',
      );
    }
    const body = (await response.json()) as {
      id: string;
      amount: number;
      currency: string;
      status: string;
    };
    return {
      gatewayOrderId: body.id,
      amountMinor: body.amount,
      currency: body.currency,
      status: body.status,
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string): boolean {
    const { webhookSecret } = this.credentials();
    const expected = createHmac('sha256', webhookSecret)
      .update(rawBody)
      .digest('hex');
    return safeEquals(expected, signature);
  }

  verifyCheckoutSignature(params: VerifyCheckoutParams): boolean {
    const { keySecret } = this.credentials();
    const expected = createHmac('sha256', keySecret)
      .update(`${params.gatewayOrderId}|${params.gatewayPaymentId}`)
      .digest('hex');
    return safeEquals(expected, params.signature);
  }
}
