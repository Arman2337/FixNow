import { Body, Controller, Get, Param, Patch, Req } from '@nestjs/common';
import { IsEnum } from 'class-validator';
import { TrustSignalStatus } from '../../../shared/trust.types';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { TrustService } from './trust.service';

class ReviewSignalDto {
  @IsEnum(TrustSignalStatus) status: TrustSignalStatus;
}

@Controller('admin/trust')
export class TrustAdminController {
  constructor(private readonly trust: TrustService) {}
  @Get('providers/:providerId/metrics')
  @RequirePermission(PERMISSIONS.trustSignalsRead)
  metrics(@Param('providerId') providerId: string) {
    return this.trust.providerMetrics(providerId);
  }
  @Get('signals')
  @RequirePermission(PERMISSIONS.trustSignalsRead)
  signals() {
    return this.trust.listSignals();
  }
  @Patch('signals/:id')
  @RequirePermission(PERMISSIONS.trustSignalsUpdate)
  review(
    @Param('id') id: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: ReviewSignalDto,
  ) {
    return this.trust.reviewSignal(
      id,
      req.authorizationPrincipal!.userId,
      dto.status,
    );
  }
}
