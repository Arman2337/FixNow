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
    return this.payments.createForBooking(
      request.authorizationPrincipal!.userId,
      dto.bookingId,
    );
  }

  @Get('orders/booking/:bookingId')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  async getForBooking(
    @Param('bookingId') bookingId: string,
    @Req() request: AuthorizedRequest,
  ): Promise<PaymentOrderContract | null> {
    return this.payments.getForBooking(
      request.authorizationPrincipal!.userId,
      bookingId,
    );
  }

  /** FN-053: the invoice generated when this payment was paid. */
  @Get('invoices/:orderId')
  @RequireOwnPermission(PERMISSIONS.paymentInvoiceReadSelf)
  async invoice(
    @Param('orderId') orderId: string,
    @Req() request: AuthorizedRequest,
  ) {
    return await this.payments.getInvoice(
      request.authorizationPrincipal!.userId,
      orderId,
    );
  }

  /** Customer-side Checkout handshake verification. */
  @Post('orders/verify')
  @RequireOwnPermission(PERMISSIONS.paymentOrderManageSelf)
  async verifyCheckout(
    @Req() request: AuthorizedRequest,
    @Body() dto: VerifyPaymentDto,
  ): Promise<PaymentOrderContract> {
    const params: Omit<VerifyCheckoutParams, 'gatewayOrderId'> = {
      gatewayPaymentId: dto.razorpayPaymentId,
      signature: dto.razorpaySignature,
    };
    return this.payments.verifyCheckout(
      request.authorizationPrincipal!.userId,
      dto.orderId,
      params,
    );
  }

  /**
   * Razorpay webhook. Public by necessity — the HMAC signature over the raw
   * body IS the authentication. Never parse before verification.
   */
  @Post('webhook')
  @Public()
  @HttpCode(HttpStatus.OK)
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
