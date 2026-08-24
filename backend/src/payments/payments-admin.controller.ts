import { Body, Controller, Headers, Param, Post, Req } from '@nestjs/common';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { CreateRefundDto } from './payments.dto';
import { PaymentsService } from './payments.service';

/**
 * FN-053 staff surface: controlled refunds and order inspection. Refunds are
 * a support/operations action — customers never self-refund.
 */
@Controller('admin/payments')
export class PaymentsAdminController {
  constructor(private readonly payments: PaymentsService) {}

  @Post('orders/:id/refunds')
  @RequirePermission(PERMISSIONS.paymentRefundCreate)
  async refund(
    @Param('id') orderId: string,
    @Req() request: AuthorizedRequest,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
    @Body() dto: CreateRefundDto,
  ) {
    const requestKey = idempotencyKey?.trim();
    if (!requestKey || requestKey.length < 8 || requestKey.length > 128) {
      return await this.payments.refundOrder(
        request.authorizationPrincipal!.userId,
        orderId,
        { amountMinor: dto.amountMinor, reason: dto.reason },
      );
    }
    return await this.payments.refundOrder(
      request.authorizationPrincipal!.userId,
      orderId,
      {
        amountMinor: dto.amountMinor,
        reason: dto.reason,
        requestKey,
      },
    );
  }
}
