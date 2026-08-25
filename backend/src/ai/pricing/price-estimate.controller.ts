import { Controller, Get, Query } from '@nestjs/common';
import { IsUUID } from 'class-validator';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../../common/authorization/permission-policies';
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
  estimate(@Query() query: PriceEstimateQueryDto) {
    return this.estimates.estimate(query.serviceCategoryId);
  }
}
