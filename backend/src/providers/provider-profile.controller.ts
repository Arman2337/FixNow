import { Body, Controller, Get, Put, Request } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { assertOwnedResource } from '../common/authorization/resource-ownership';
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
  async getOwnProfile(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderProfileResponseDto> {
    const principal = request.authorizationPrincipal!;
    const profile = await this.profileService.getOwnProfile(principal.userId);
    // SEC-002: the response carries the profile's real `userId`, so compare it.
    assertOwnedResource(principal, profile.userId, 'providerProfile.userId');
    return profile;
  }

  @Put('me')
  @RequireOwnPermission('provider.profile.update')
  async upsertOwnProfile(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpsertProviderProfileDto,
  ): Promise<ProviderProfileResponseDto> {
    const principal = request.authorizationPrincipal!;
    const profile = await this.profileService.upsertOwnProfile(
      principal.userId,
      dto,
    );
    assertOwnedResource(principal, profile.userId, 'providerProfile.userId');
    return profile;
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
  async updateOwnLocation(
    @Request() request: AuthorizedRequest,
    @Body() dto: UpdateProviderLocationDto,
  ): Promise<ProviderProfileResponseDto> {
    const principal = request.authorizationPrincipal!;
    const profile = await this.profileService.updateLocation(
      principal.userId,
      dto,
    );
    assertOwnedResource(principal, profile.userId, 'providerProfile.userId');
    return profile;
  }

  @Put('me/coverage-check')
  @RequireOwnPermission('provider.profile.read')
  checkOwnCoverage(
    @Request() request: AuthorizedRequest,
    @Body() dto: CoverageCheckDto,
  ): Promise<CoverageCheckResponseDto> {
    // SEC-002: the answer is a bare boolean with no owner column, so the
    // comparison has to happen where the profile is loaded.
    return this.profileService.checkCoverage(
      request.authorizationPrincipal!,
      dto,
    );
  }
}
