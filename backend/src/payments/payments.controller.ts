import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  Public,
  RequireOwnPermission,
} from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type {
  PaymentOrderContract,
  VerifyCheckoutParams,
} from '../../../shared/payments.types';
import { CreatePaymentOrderDto, VerifyPaymentDto } from './payments.dto';
import { PaymentsService } from './payments.service';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  /** FN-052: booking-bound order creation; idempotent per booking. */
  @Post('orders')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  async createOrder(
    @Req() request: AuthorizedRequest,
    @Body() dto: CreatePaymentOrderDto,
  ): Promise<PaymentOrderContract> {
    const principal = request.authorizationPrincipal!;
    return this.payments.createForBooking(
      principal.userId,
      dto.bookingId,
      principal,
    );
  }

  @Get('orders/booking/:bookingId')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  async getForBooking(
    @Param('bookingId') bookingId: string,
    @Req() request: AuthorizedRequest,
  ): Promise<PaymentOrderContract | null> {
    const principal = request.authorizationPrincipal!;
    return this.payments.getForBooking(principal.userId, bookingId, principal);
  }

  /** FN-053: the invoice generated when this payment was paid. */
  @Get('invoices/:orderId')
  @RequireOwnPermission(PERMISSIONS.paymentInvoiceReadSelf)
  async invoice(
    @Param('orderId') orderId: string,
    @Req() request: AuthorizedRequest,
  ) {
    // SEC-002: discharged on the stored order — the invoice projection carries
    // no owner column.
    return await this.payments.getInvoice(
      request.authorizationPrincipal!.userId,
      orderId,
      request.authorizationPrincipal,
    );
  }

  /** Customer-side Checkout handshake verification. */
  @Post('orders/verify')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  async verifyCheckout(
    @Req() request: AuthorizedRequest,
    @Body() dto: VerifyPaymentDto,
  ): Promise<PaymentOrderContract> {
    const principal = request.authorizationPrincipal!;
    const params: Omit<VerifyCheckoutParams, 'gatewayOrderId'> = {
      gatewayPaymentId: dto.razorpayPaymentId,
      signature: dto.razorpaySignature,
    };
    return this.payments.verifyCheckout(
      principal.userId,
      dto.orderId,
      params,
      principal,
    );
  }

  /**
   * Razorpay webhook. Public by necessity — the HMAC signature over the raw
   * body IS the authentication. Never parse before verification.
   *
   * SEC-002: confirmed `@Public()`, so the guard returns before it raises any
   * deferred obligation and `OwnershipProofInterceptor` has nothing to check
   * (it also returns early when there is no principal). There is correctly no
   * discharge call here, and there must not be one: the caller is the gateway,
   * not a user, and there is no principal to compare.
   */
  @Post('webhook')
  @Public()
  @HttpCode(HttpStatus.OK)
  // API-002: unauthenticated, so it would otherwise share the global 60/min
  // bucket. The gateway retries on a non-2xx, and it fans out one webhook per
  // payment event, so a legitimate burst can be larger than that — hence a
  // separate, higher limit rather than none. Signatures that fail verification
  // are rejected inside `processWebhook`, so this bound is about protecting the
  // process, not about authenticating the caller.
  @Throttle({ default: { limit: 300, ttl: 60_000 } })
  async webhook(
    @Req() request: AuthorizedRequest & { rawBody?: Buffer },
  ): Promise<{ handled: boolean; duplicate?: boolean }> {
    const rawBody = request.rawBody;
    if (!rawBody || !Buffer.isBuffer(rawBody)) {
      throw new BadRequestException('Raw webhook body unavailable');
    }
    const signature = request.headers['x-razorpay-signature'];
    return this.payments.processWebhook(
      rawBody,
      Array.isArray(signature) ? signature[0] : signature,
    );
  }
}
