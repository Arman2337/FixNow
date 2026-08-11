import { Body, Controller, Get, Put, Request } from '@nestjs/common';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import {
  ProviderAvailabilityResponseDto,
  UpdateProviderScheduleDto,
  UpdateProviderStatusDto,
} from './provider-availability.dto';
import { ProviderAvailabilityService } from './provider-availability.service';

@Controller('provider-availability')
export class ProviderAvailabilityController {
  constructor(private readonly service: ProviderAvailabilityService) {}

  @Get('me')
  @RequireOwnPermission('provider.availability.read')
  getOwn(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderAvailabilityResponseDto> {
    return this.service.getOwn(request.authorizationPrincipal!.userId);
  }

  @Put('me/schedule')
  @RequireOwnPermission('provider.availability.update')
  updateSchedule(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpdateProviderScheduleDto,
  ): Promise<ProviderAvailabilityResponseDto> {
    return this.service.updateSchedule(
      request.authorizationPrincipal!.userId,
      dto,
    );
  }

  @Put('me/status')
  @RequireOwnPermission('provider.availability.update')
  updateStatus(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpdateProviderStatusDto,
  ): Promise<ProviderAvailabilityResponseDto> {
    return this.service.updateStatus(
      request.authorizationPrincipal!.userId,
      dto,
    );
  }
}
