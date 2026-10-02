import { Body, Controller, Get, Patch, Req } from '@nestjs/common';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { assertNoResourceToProve } from '../common/authorization/resource-ownership';
import {
  CustomerProfileResponse,
  UpdateCustomerProfileDto,
} from './customer-profile.dto';
import { CustomerProfileService } from './customer-profile.service';

@Controller('users/me/profile')
export class CustomerProfileController {
  constructor(private readonly profiles: CustomerProfileService) {}

  @Get()
  @RequireOwnPermission(PERMISSIONS.profileReadSelf)
  read(@Req() request: AuthorizedRequest): Promise<CustomerProfileResponse> {
    // SEC-002: the profile is looked up *by* the principal's own id, and the
    // response deliberately carries no owner column, so there is nothing to
    // compare — say that explicitly instead of leaving the obligation open.
    assertNoResourceToProve(request.authorizationPrincipal);
    return this.profiles.read(request.authorizationPrincipal!.userId);
  }

  @Patch()
  @RequireOwnPermission(PERMISSIONS.profileUpdateSelf)
  update(
    @Req() request: AuthorizedRequest,
    @Body() input: UpdateCustomerProfileDto,
  ): Promise<CustomerProfileResponse> {
    assertNoResourceToProve(request.authorizationPrincipal);
    return this.profiles.update(
      request.authorizationPrincipal!.userId,
      input.displayName,
    );
  }
}
