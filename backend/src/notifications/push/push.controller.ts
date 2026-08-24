import { Body, Controller, Delete, Get, Param, Put, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { PERMISSIONS } from '../../common/authorization/permission-policies';
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
    return this.devices.register(request.authorizationPrincipal!.userId, input);
  }

  @Get()
  @RequireOwnPermission(PERMISSIONS.pushTokenManageSelf)
  list(@Req() request: AuthorizedRequest): Promise<PushDeviceResponse[]> {
    return this.devices.list(request.authorizationPrincipal!.userId);
  }

  @Delete(':id')
  @RequireOwnPermission(PERMISSIONS.pushTokenManageSelf)
  async revoke(
    @Req() request: AuthorizedRequest,
    @Param('id') deviceId: string,
  ): Promise<void> {
    await this.devices.revoke(request.authorizationPrincipal!.userId, deviceId);
  }
}
