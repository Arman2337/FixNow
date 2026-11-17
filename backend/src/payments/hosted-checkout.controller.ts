import {
  Body,
  ConflictException,
  Controller,
  Get,
  Header,
  HttpCode,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { Repository } from 'typeorm';
import {
  Public,
  RequireOwnPermission,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { PaymentOrderContract } from '../../../shared/payments.types';
import { PaymentOrder } from './domain/payment-order.entity';
import { CheckoutTokenDto, ConfirmGroupServiceDto } from './payments.dto';
import { PaymentsService } from './payments.service';

const idPipe = new ParseUUIDPipe({ version: '4' });
const ttlSeconds = 600;

const checkoutScript = `
  const status = document.getElementById('status');
  const button = document.getElementById('pay');
  const token = location.hash.slice(1);
  history.replaceState(null, '', location.pathname);
  function loadCheckout() {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://checkout.razorpay.com/v1/checkout.js';
      script.onload = resolve;
      script.onerror = reject;
      document.head.append(script);
    });
  }
  async function prepare() {
    const response = await fetch('checkout/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }),
    });
    if (!response.ok) throw new Error();
    const order = await response.json();
    await loadCheckout();
    if (typeof Razorpay !== 'function') throw new Error();
    status.textContent = 'Amount due ' + new Intl.NumberFormat('en-IN', {
      style: 'currency', currency: 'INR'
    }).format(order.amount / 100);
    button.hidden = false;
    button.addEventListener('click', () => {
      button.disabled = true;
      const checkout = new Razorpay({
        ...order,
        name: 'FixNow',
        description: 'Service payment',
        config: {
          display: {
            blocks: { upi: { name: 'UPI', instruments: [{ method: 'upi' }] } },
            sequence: ['block.upi'],
            preferences: { show_default_blocks: false },
          },
        },
        handler: () => {
          button.hidden = true;
          status.textContent = 'Payment submitted. Return to FixNow to check confirmation.';
        },
        modal: {
          ondismiss: () => {
            button.disabled = false;
            status.textContent = 'Checkout closed. Check the payment status in FixNow before trying again.';
          },
        },
      });
      checkout.open();
    });
  }
  prepare().catch(() => {
    status.textContent = 'Checkout is unavailable or the link expired. Return to FixNow to check your payment.';
  });
`;
const pageScript = `window.addEventListener('DOMContentLoaded', () => {${checkoutScript}});`;
const checkoutScriptHash = createHash('sha256')
  .update(pageScript)
  .digest('base64');
const checkoutCsp = [
  "default-src 'none'",
  "base-uri 'none'",
  "frame-ancestors 'none'",
  "form-action 'none'",
  `script-src 'sha256-${checkoutScriptHash}' https://checkout.razorpay.com https://cdn.razorpay.com`,
  "connect-src 'self' https://*.razorpay.com",
  'frame-src https://*.razorpay.com',
  "style-src 'unsafe-inline'",
  'img-src https://*.razorpay.com data:',
].join('; ');

@Controller('payments')
export class HostedCheckoutController {
  constructor(
    private readonly config: ConfigService,
    private readonly payments: PaymentsService,
    @InjectRepository(PaymentOrder)
    private readonly orders: Repository<PaymentOrder>,
  ) {}

  @Get('checkout/availability')
  @Header('Cache-Control', 'no-store')
  @RequirePermission(PERMISSIONS.paymentCheckoutRead)
  availability() {
    return { available: this.isEnabled() };
  }

  @Post('checkout/bookings/:id')
  @Header('Cache-Control', 'no-store')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  async startBooking(
    @Req() req: AuthorizedRequest,
    @Param('id', idPipe) id: string,
  ) {
    this.assertEnabled();
    const principal = req.authorizationPrincipal!;
    return this.issue(
      await this.payments.createForBooking(principal.userId, id, principal),
    );
  }

  @Get('orders/group-services/:id')
  @Header('Cache-Control', 'no-store')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  groupOrder(@Req() req: AuthorizedRequest, @Param('id', idPipe) id: string) {
    const principal = req.authorizationPrincipal!;
    return this.payments.groupOrder(principal.userId, id, principal);
  }

  @Post('checkout/group-services/:id')
  @Header('Cache-Control', 'no-store')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  async startGroup(
    @Req() req: AuthorizedRequest,
    @Param('id', idPipe) id: string,
    @Body() confirmation: ConfirmGroupServiceDto,
  ) {
    this.assertEnabled();
    const principal = req.authorizationPrincipal!;
    return this.issue(
      await this.payments.groupOrder(
        principal.userId,
        id,
        principal,
        confirmation.serviceReceived,
      ),
    );
  }

  @Get('checkout')
  @Header('Cache-Control', 'no-store')
  @Public()
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Content-Security-Policy', checkoutCsp)
  @Header('Referrer-Policy', 'no-referrer')
  page() {
    this.assertEnabled();
    return `<!doctype html><html lang="en"><head><meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>FixNow UPI Checkout</title>
      </head><body style="font-family: system-ui; color: #14332a; background: #f6faf8; padding: 24px">
      <main style="max-width: 30rem; margin: auto"><h1>FixNow UPI checkout</h1>
      <p id="status" role="status">Loading your payment</p>
      <button id="pay" hidden style="padding: 12px 20px">Pay with UPI</button>
      </main><script>${pageScript}</script>
      </body></html>`;
  }

  @Post('checkout/session')
  @Header('Cache-Control', 'no-store')
  @Public()
  @HttpCode(200)
  async session(@Body() dto: CheckoutTokenDto) {
    this.assertEnabled();
    const [id, expiration, signature] = dto.token.split('.');
    const expected = this.sign(`${id}.${expiration}`);
    if (
      !timingSafeEqual(
        Buffer.from(signature, 'hex'),
        Buffer.from(expected, 'hex'),
      ) ||
      Number(expiration) <= Math.floor(Date.now() / 1000)
    ) {
      throw new NotFoundException('Checkout session is unavailable');
    }
    const order = await this.orders.findOneBy({ id });
    if (!order || !this.isPayable(order.status)) {
      throw new NotFoundException('Checkout session is unavailable');
    }
    return {
      key: this.config.getOrThrow<string>('RAZORPAY_KEY_ID'),
      order_id: order.gatewayOrderId,
      currency: order.currency,
      amount: order.amountMinor,
    };
  }

  private issue(order: PaymentOrderContract | null) {
    if (!order || !this.isPayable(order.status)) {
      throw new ConflictException('This payment has already been finalized');
    }
    const payload = `${order.id}.${Math.floor(Date.now() / 1000) + ttlSeconds}`;
    return { token: `${payload}.${this.sign(payload)}` };
  }

  private isPayable(status: PaymentOrderContract['status']) {
    return status === 'CREATED' || status === 'FAILED';
  }

  private sign(payload: string) {
    return createHmac('sha256', this.config.getOrThrow<string>('JWT_SECRET'))
      .update(`fixnow:razorpay-checkout:v1:${payload}`)
      .digest('hex');
  }

  private isEnabled() {
    return this.config.get<string>('PAYMENT_PROVIDER') === 'razorpay';
  }

  private assertEnabled() {
    if (!this.isEnabled())
      throw new ServiceUnavailableException(
        'Online UPI checkout is unavailable',
      );
  }
}
