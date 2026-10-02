import { Body, Controller, Get, Put, Request } from '@nestjs/common';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { assertOwnedResource } from '../../common/authorization/resource-ownership';
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
  async getOwn(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderAvailabilityResponseDto> {
    const principal = request.authorizationPrincipal!;
    const availability = await this.service.getOwn(principal.userId);
    // SEC-002: every /me availability route reads or writes the caller's own
    // row, keyed by the principal. The response carries that row's real
    // `userId`, so compare rather than assume.
    assertOwnedResource(
      principal,
      availability.userId,
      'providerAvailability.userId',
    );
    return availability;
  }

  @Put('me/schedule')
  @RequireOwnPermission('provider.availability.update')
  async updateSchedule(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpdateProviderScheduleDto,
  ): Promise<ProviderAvailabilityResponseDto> {
    const principal = request.authorizationPrincipal!;
    const availability = await this.service.updateSchedule(
      principal.userId,
      dto,
    );
    assertOwnedResource(
      principal,
      availability.userId,
      'providerAvailability.userId',
    );
    return availability;
  }

  @Put('me/status')
  @RequireOwnPermission('provider.availability.update')
  async updateStatus(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpdateProviderStatusDto,
  ): Promise<ProviderAvailabilityResponseDto> {
    const principal = request.authorizationPrincipal!;
    const availability = await this.service.updateStatus(principal.userId, dto);
    assertOwnedResource(
      principal,
      availability.userId,
      'providerAvailability.userId',
    );
    return availability;
  }
}
