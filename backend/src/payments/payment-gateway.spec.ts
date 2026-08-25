import { ConfigService } from '@nestjs/config';
import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHmac } from 'crypto';
import {
  FakePaymentGateway,
  RazorpayPaymentGateway,
  assertSupportedPaymentAmount,
} from './payment-gateway';

const CREDENTIALS = {
  RAZORPAY_KEY_ID: 'rzp_test_authorized',
  RAZORPAY_KEY_SECRET: 'test-key-secret',
  RAZORPAY_WEBHOOK_SECRET: 'test-webhook-secret',
};

function razorpayWith(
  overrides: Record<string, string> = {},
): RazorpayPaymentGateway {
  const config = {
    get: (name: string) => overrides[name] ?? CREDENTIALS[name],
  } as unknown as ConfigService;
  return new RazorpayPaymentGateway(config);
}

describe('FakePaymentGateway', () => {
  const gateway = new FakePaymentGateway();

  it('creates deterministic orders with integer paise amounts', async () => {
    const first = await gateway.createOrder({
      amountMinor: 49900,
      currency: 'INR',
      receipt: 'booking-1',
    });
    const second = await gateway.createOrder({
      amountMinor: 49900,
      currency: 'INR',
      receipt: 'booking-1',
    });
    expect(first.gatewayOrderId).toMatch(/^order_fake_\d+$/);
    expect(second.gatewayOrderId).not.toBe(first.gatewayOrderId);
    expect(first.amountMinor).toBe(49900);
    expect(gateway.orders).toHaveLength(2);
  });

  it('verifies only its own deterministic signatures', () => {
    expect(gateway.verifyWebhookSignature('{"event":"x"}', 'fake-13')).toBe(
      true,
    );
    expect(gateway.verifyWebhookSignature('{"event":"x"}', 'nope')).toBe(false);
    expect(
      gateway.verifyCheckoutSignature({
        gatewayOrderId: 'order_fake_1',
        gatewayPaymentId: 'pay_1',
        signature: 'fake-order_fake_1:pay_1',
      }),
    ).toBe(true);
    expect(
      gateway.verifyCheckoutSignature({
        gatewayOrderId: 'order_fake_1',
        gatewayPaymentId: 'pay_1',
        signature: 'forged',
      }),
    ).toBe(false);
  });
});

describe('RazorpayPaymentGateway signature verification', () => {
  it('accepts a correctly computed webhook HMAC and rejects tampering', () => {
    const gateway = razorpayWith();
    const rawBody = JSON.stringify({
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'pay_1' } } },
    });
    const valid = createHmac('sha256', CREDENTIALS.RAZORPAY_WEBHOOK_SECRET)
      .update(rawBody)
      .digest('hex');

    expect(gateway.verifyWebhookSignature(rawBody, valid)).toBe(true);
    expect(gateway.verifyWebhookSignature(rawBody, `${valid}0`)).toBe(false);
    expect(gateway.verifyWebhookSignature(`${rawBody} `, valid)).toBe(false);
  });

  it('accepts the checkout handshake HMAC of order|payment and rejects forgeries', () => {
    const gateway = razorpayWith();
    const valid = createHmac('sha256', CREDENTIALS.RAZORPAY_KEY_SECRET)
      .update('order_1|pay_1')
      .digest('hex');

    expect(
      gateway.verifyCheckoutSignature({
        gatewayOrderId: 'order_1',
        gatewayPaymentId: 'pay_1',
        signature: valid,
      }),
    ).toBe(true);
    expect(
      gateway.verifyCheckoutSignature({
        gatewayOrderId: 'order_1',
        gatewayPaymentId: 'pay_2', // swapped payment id
        signature: valid,
      }),
    ).toBe(false);
  });

  it('throws a configuration error only when actually used without credentials', () => {
    const unconfigured = razorpayWith({
      RAZORPAY_KEY_ID: '',
      RAZORPAY_KEY_SECRET: '',
      RAZORPAY_WEBHOOK_SECRET: '',
    });
    expect(() => unconfigured.verifyWebhookSignature('{}', 'sig')).toThrow(
      ServiceUnavailableException,
    );
  });

  it('creates orders over the REST surface with basic auth and paise amounts', async () => {
    const fetchMock = jest
      .fn<Promise<Response>, [string, RequestInit]>()
      .mockResolvedValue(
        new Response(
          JSON.stringify({
            id: 'order_XYZ',
            amount: 49900,
            currency: 'INR',
            status: 'created',
          }),
          { status: 201 },
        ),
      );
    jest.spyOn(global, 'fetch').mockImplementation(fetchMock);
    try {
      const order = await razorpayWith().createOrder({
        amountMinor: 49900,
        currency: 'INR',
        receipt: 'booking-1',
      });
      expect(order.gatewayOrderId).toBe('order_XYZ');
      const [url, init] = fetchMock.mock.calls[0];
      expect(url).toBe('https://api.razorpay.com/v1/orders');
      expect(init.method).toBe('POST');
      const auth = (init.headers as Record<string, string>).Authorization;
      expect(auth).toBe(
        `Basic ${Buffer.from(
          `${CREDENTIALS.RAZORPAY_KEY_ID}:${CREDENTIALS.RAZORPAY_KEY_SECRET}`,
        ).toString('base64')}`,
      );
      expect(JSON.parse(init.body)).toEqual({
        amount: 49900,
        currency: 'INR',
        receipt: 'booking-1',
        notes: {},
      });
    } finally {
      jest.restoreAllMocks();
    }
  });

  it('maps gateway rejections to a safe service error without leaking details', async () => {
    jest
      .spyOn(global, 'fetch')
      .mockResolvedValue(new Response('unauthorized', { status: 401 }));
    try {
      await expect(
        razorpayWith().createOrder({
          amountMinor: 49900,
          currency: 'INR',
          receipt: 'booking-1',
        }),
      ).rejects.toBeInstanceOf(ServiceUnavailableException);
    } finally {
      jest.restoreAllMocks();
    }
  });
});

describe('assertSupportedPaymentAmount', () => {
  it('accepts bounded integer paise', () => {
    expect(() => assertSupportedPaymentAmount(1, 'INR')).not.toThrow();
    expect(() => assertSupportedPaymentAmount(100_000_00, 'INR')).not.toThrow();
  });
  it.each([
    [0, 'INR'],
    [-100, 'INR'],
    [499.5, 'INR'],
    [49900, 'USD'],
    [100_000_01, 'INR'],
  ])('rejects %s %s', (amountMinor: number, currency: string) => {
    expect(() => assertSupportedPaymentAmount(amountMinor, currency)).toThrow(
      BadRequestException,
    );
  });
});
