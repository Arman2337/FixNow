import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Query,
  Req,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { TrustSignalStatus } from '../../../shared/trust.types';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { TrustService } from './trust.service';

class ReviewSignalDto {
  @IsEnum(TrustSignalStatus) status: TrustSignalStatus;
}

export class TrustSignalsPageQueryDto {
  @IsOptional() @IsEnum(TrustSignalStatus) status?: TrustSignalStatus;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 20;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) offset = 0;
  @IsOptional() @IsString() cursor?: string;
}

@Controller('admin/trust')
export class TrustAdminController {
  constructor(private readonly trust: TrustService) {}
  @Get('providers/:providerId/metrics')
  @RequirePermission(PERMISSIONS.trustSignalsRead)
  metrics(@Param('providerId') providerId: string) {
    return this.trust.providerMetrics(providerId);
  }
  @Get('providers/:providerId/accept-time')
  @RequirePermission(PERMISSIONS.trustSignalsRead)
  acceptTime(@Param('providerId') providerId: string) {
    return this.trust.providerAcceptTime(providerId);
  }
  @Get('signals')
  @RequirePermission(PERMISSIONS.trustSignalsRead)
  signals(@Query() query: TrustSignalsPageQueryDto) {
    return this.trust.listSignals(query.limit, query.offset, query.status);
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
