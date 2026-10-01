import { Body, Controller, Get, Put, Request } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  CoverageCheckDto,
  CoverageCheckResponseDto,
  ProviderProfileResponseDto,
  UpdateProviderLocationDto,
  UpsertProviderProfileDto,
} from './provider-profile.dto';
import { ProviderProfileService } from './provider-profile.service';

@Controller('provider-profile')
export class ProviderProfileController {
  constructor(private readonly profileService: ProviderProfileService) {}

  @Get('me')
  @RequireOwnPermission('provider.profile.read')
  getOwnProfile(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderProfileResponseDto> {
    return this.profileService.getOwnProfile(
      request.authorizationPrincipal!.userId,
    );
  }

  @Put('me')
  @RequireOwnPermission('provider.profile.update')
  upsertOwnProfile(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpsertProviderProfileDto,
  ): Promise<ProviderProfileResponseDto> {
    return this.profileService.upsertOwnProfile(
      request.authorizationPrincipal!.userId,
      dto,
    );
  }

  /**
   * BUG-016. Rate-limited far below the global 60/min.
   *
   * These coordinates are the sole input to dispatch distance, so this endpoint
   * is not a profile field - it is a lever on which jobs a provider is offered.
   * At the global limit a provider could re-centre themselves on a dense area as
   * fast as the API would answer, and no audit row recorded any of it.
   *
   * Six per hour is generous for a genuine use (a provider who moved, or whose
   * phone's location fix was wrong when they registered) while making farming
   * impractical. The freshness bound in `MatchingService` is the durable
   * protection; this is the cheap one that stops the abuse in the first place.
   */
  @Throttle({ default: { limit: 6, ttl: 60 * 60_000 } })
  @Put('me/location')
  @RequireOwnPermission('provider.profile.update')
  updateOwnLocation(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpdateProviderLocationDto,
  ): Promise<ProviderProfileResponseDto> {
    return this.profileService.updateLocation(
      request.authorizationPrincipal!.userId,
      dto,
    );
  }

  @Put('me/coverage-check')
  @RequireOwnPermission('provider.profile.read')
  checkOwnCoverage(
    @Request() request: AuthorizedRequest,
    @Body() dto: CoverageCheckDto,
  ): Promise<CoverageCheckResponseDto> {
    return this.profileService.checkCoverage(
      request.authorizationPrincipal!.userId,
      dto,
    );
  }
}
