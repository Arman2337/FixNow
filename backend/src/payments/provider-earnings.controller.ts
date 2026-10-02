import { Controller, Get, Param, Req } from '@nestjs/common';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { assertNoResourceToProve } from '../common/authorization/resource-ownership';
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
    // SEC-002: aggregates over the caller's own completed payments. No
    // caller-named resource, and the ledger deliberately names no owner.
    assertNoResourceToProve(request.authorizationPrincipal);
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
    // SEC-002: `{ bookingId, paid }` carries no owner column, so the service
    // discharges against the booking's `providerId` after checking it.
    return await this.payments.providerBookingPaymentStatus(
      request.authorizationPrincipal!.userId,
      bookingId,
      request.authorizationPrincipal,
    );
  }
}
