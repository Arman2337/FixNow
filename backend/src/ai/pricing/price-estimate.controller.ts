import { Controller, Get, Query, Req } from '@nestjs/common';
import { IsUUID } from 'class-validator';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { assertNoResourceToProve } from '../../common/authorization/resource-ownership';
import { PriceEstimateService } from './price-estimate.service';

class PriceEstimateQueryDto {
  @IsUUID()
  serviceCategoryId!: string;
}

/** FN-060: customer-facing advisory price range. Read-only, no booking effect. */
@Controller('ai/price-estimate')
export class PriceEstimateController {
  constructor(private readonly estimates: PriceEstimateService) {}

  @Get()
  @RequireOwnPermission(PERMISSIONS.aiPriceEstimateReadSelf)
  estimate(
    @Req() request: AuthorizedRequest,
    @Query() query: PriceEstimateQueryDto,
  ) {
    // SEC-002: a read-only advisory over published category pricing. Nothing in
    // the request names a resource owned by the caller, and nothing is stored,
    // so there is no ownership to prove.
    assertNoResourceToProve(request.authorizationPrincipal);
    return this.estimates.estimate(query.serviceCategoryId);
  }
}
