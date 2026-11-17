import {
  ConflictException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'node:crypto';
import { HostedCheckoutController } from './hosted-checkout.controller';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

describe('HostedCheckoutController', () => {
  const id = 'ac4895db-5bda-4fb8-a9ca-66064d4aa702';
  const principal = {
    userId: 'customer',
    sessionId: 'session',
    roles: ['customer'],
  };
  const request = { authorizationPrincipal: principal } as AuthorizedRequest;
  const order = {
    id,
    amountMinor: 49900,
    currency: 'INR',
    gatewayOrderId: 'order_test',
    status: 'CREATED',
  };
  const payments = { createForBooking: jest.fn(), groupOrder: jest.fn() };
  const orders = { findOneBy: jest.fn() };
  let controller: HostedCheckoutController;

  beforeEach(() => {
    jest.clearAllMocks();
    payments.createForBooking.mockResolvedValue(order);
    payments.groupOrder.mockResolvedValue(order);
    orders.findOneBy.mockResolvedValue(order);
    controller = new HostedCheckoutController(
      new ConfigService({
        PAYMENT_PROVIDER: 'razorpay',
        RAZORPAY_KEY_ID: 'rzp_test_publickey',
        JWT_SECRET: 'test-secret-for-signing-checkout-links',
      }),
      payments as never,
      orders as never,
    );
  });

  it('issues a short-lived capability after the service authorizes the booking', async () => {
    const { token } = await controller.startBooking(request, id);
    expect(payments.createForBooking).toHaveBeenCalledWith(
      'customer',
      id,
      principal,
    );
    expect(await controller.session({ token })).toEqual({
      key: 'rzp_test_publickey',
      order_id: 'order_test',
      amount: 49900,
      currency: 'INR',
    });
    const changed = token.slice(0, -1) + (token.endsWith('0') ? '1' : '0');
    await expect(controller.session({ token: changed })).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('expires the session and refuses to reopen paid orders', async () => {
    const { token } = await controller.startGroup(request, id, {
      serviceReceived: true,
    });
    expect(payments.groupOrder).toHaveBeenCalledWith(
      'customer',
      id,
      principal,
      true,
    );
    orders.findOneBy.mockResolvedValue({ ...order, status: 'PAID' });
    await expect(controller.session({ token })).rejects.toBeInstanceOf(
      NotFoundException,
    );
    payments.createForBooking.mockResolvedValue({ ...order, status: 'PAID' });
    await expect(controller.startBooking(request, id)).rejects.toBeInstanceOf(
      ConflictException,
    );
    const clock = jest
      .spyOn(Date, 'now')
      .mockReturnValueOnce(Date.now() + 601_000);
    orders.findOneBy.mockResolvedValue(order);
    try {
      await expect(controller.session({ token })).rejects.toBeInstanceOf(
        NotFoundException,
      );
    } finally {
      clock.mockRestore();
    }
  });

  it('does not open hosted checkout on the fake gateway', async () => {
    const fake = new HostedCheckoutController(
      new ConfigService({ PAYMENT_PROVIDER: 'fake' }),
      payments as never,
      orders as never,
    );
    expect(fake.availability()).toEqual({ available: false });
    await expect(fake.startBooking(request, id)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(payments.createForBooking).not.toHaveBeenCalled();
  });

  it('allows the actual inline checkout script under the route CSP', () => {
    const html = controller.page();
    const script = /<script>([\s\S]*)<\/script>/.exec(html)![1];
    const hash = createHash('sha256').update(script).digest('base64');
    const headers = Reflect.getMetadata('__headers__', controller.page) as {
      name: string;
      value: string;
    }[];
    expect(
      headers.find(({ name }) => name === 'Content-Security-Policy')?.value,
    ).toContain(`'sha256-${hash}'`);
  });
});
