import { Body, Controller, Get, Put, Request } from '@nestjs/common';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  CoverageCheckDto,
  CoverageCheckResponseDto,
  ProviderProfileResponseDto,
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
