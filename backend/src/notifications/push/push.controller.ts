import { Body, Controller, Delete, Get, Param, Put, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { PERMISSIONS } from '../../common/authorization/permission-policies';
import {
  assertNoResourceToProve,
  assertOwnedResource,
} from '../../common/authorization/resource-ownership';
// Value import: a type-only DTO import is erased at runtime and the global
// validation whitelist would then reject every request body property.
import { RegisterPushDeviceDto } from './push.dto';
import type { PushDeviceResponse } from './push.dto';
import { PushDeviceService } from './push.service';

@Controller('notifications/push/devices')
export class PushDeviceController {
  constructor(private readonly devices: PushDeviceService) {}

  @Put()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @RequireOwnPermission(PERMISSIONS.pushTokenManageSelf)
  register(
    @Req() request: AuthorizedRequest,
    @Body() input: RegisterPushDeviceDto,
  ): Promise<PushDeviceResponse> {
    // SEC-002: registration binds the token to the caller, so the row is the
    // caller's by construction and the response carries no owner column.
    assertNoResourceToProve(request.authorizationPrincipal);
    return this.devices.register(request.authorizationPrincipal!.userId, input);
  }

  @Get()
  @RequireOwnPermission(PERMISSIONS.pushTokenManageSelf)
  list(@Req() request: AuthorizedRequest): Promise<PushDeviceResponse[]> {
    // SEC-002: scoped by the principal's own id inside the service; the
    // projected response intentionally omits `userId`, so there is no row to
    // compare.
    assertNoResourceToProve(request.authorizationPrincipal);
    return this.devices.list(request.authorizationPrincipal!.userId);
  }

  @Delete(':id')
  @RequireOwnPermission(PERMISSIONS.pushTokenManageSelf)
  async revoke(
    @Req() request: AuthorizedRequest,
    @Param('id') deviceId: string,
  ): Promise<void> {
    const principal = request.authorizationPrincipal!;
    // SEC-002: `revoke` now returns the row it removed, so the owning column is
    // still available to compare after the delete.
    const revoked = await this.devices.revoke(principal.userId, deviceId);
    assertOwnedResource(principal, revoked.userId, 'pushDeviceToken.userId');
  }
}
