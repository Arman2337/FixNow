import { Controller, Get, Param, Req } from '@nestjs/common';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { PaymentsService } from './payments.service';

/**
 * FN-053: the provider's own honest earnings ledger. Records of completed
 * payments minus refunds — never a payout promise (ADR-0016).
 */
@Controller('providers')
export class ProviderEarningsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get('me/earnings')
  @RequireOwnPermission(PERMISSIONS.providerEarningsReadSelf)
  async earnings(@Req() request: AuthorizedRequest) {
    return await this.payments.providerEarnings(
      request.authorizationPrincipal!.userId,
    );
  }

  @Get('me/bookings/:bookingId/payment-status')
  @RequireOwnPermission(PERMISSIONS.providerEarningsReadSelf)
  async bookingPaymentStatus(
    @Param('bookingId') bookingId: string,
    @Req() request: AuthorizedRequest,
  ) {
    return await this.payments.providerBookingPaymentStatus(
      request.authorizationPrincipal!.userId,
      bookingId,
    );
  }
}
