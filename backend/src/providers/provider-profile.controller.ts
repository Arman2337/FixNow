import { Body, Controller, Get, Put, Request } from '@nestjs/common';
import { ConfigurableThrottle } from '../common/throttling/configurable-throttle.decorator';
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
   * BUG-016. Rate-limited far below the global 60/min, and configurable.
   *
   * These coordinates are the sole input to dispatch distance, so this endpoint
   * is not a profile field - it is a lever on which jobs a provider is offered.
   * At the global limit a provider could re-centre themselves on a dense area as
   * fast as the API would answer, and no audit row recorded any of it.
   *
   * The allowance used to be a `@Throttle` constant, which put it in the
   * compiled controller: an operator who hit the limit during testing had no
   * way to relieve it but a code change and a redeploy. It is now read from
   * `PROVIDER_LOCATION_THROTTLE_LIMIT` / `PROVIDER_LOCATION_THROTTLE_TTL_MS`
   * per request, so a deployment can tune it without shipping. The policy
   * itself is unchanged - still well below the global bucket, and still the
   * cheap outer bound over the freshness check in `MatchingService`, which is
   * the durable one.
   */
  @ConfigurableThrottle({
    limitKey: 'PROVIDER_LOCATION_THROTTLE_LIMIT',
    ttlKey: 'PROVIDER_LOCATION_THROTTLE_TTL_MS',
  })
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
