import { Body, Controller, Get, Patch, Req } from '@nestjs/common';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
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
    return this.profiles.read(request.authorizationPrincipal!.userId);
  }

  @Patch()
  @RequireOwnPermission(PERMISSIONS.profileUpdateSelf)
  update(
    @Req() request: AuthorizedRequest,
    @Body() input: UpdateCustomerProfileDto,
  ): Promise<CustomerProfileResponse> {
    return this.profiles.update(
      request.authorizationPrincipal!.userId,
      input.displayName,
    );
  }
}
