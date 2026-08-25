import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { IsUUID } from 'class-validator';
import {
  RequireOwnPermission,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { CreateBookingDto } from '../bookings/bookings.dto';
import { EmergencyService } from './emergency.service';

class EmergencyRequestDto extends CreateBookingDto {}

class EmergencyIdParam {
  @IsUUID()
  bookingId!: string;
}

/**
 * FN-063 endpoints (policy §3/§9). Creation is the deliberate second step
 * of the two-step confirm journey; the Idempotency-Key header protects
 * against double-taps under stress.
 */
@Controller('emergency')
export class EmergencyController {
  constructor(private readonly emergency: EmergencyService) {}

  @Post('requests')
  @RequireOwnPermission(PERMISSIONS.emergencyCreateSelf)
  create(
    @Req() request: AuthorizedRequest,
    @Body() body: EmergencyRequestDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.emergency.createEmergency(
      request.authorizationPrincipal!.userId,
      body,
      idempotencyKey ?? '',
    );
  }

  @Get('requests/:bookingId')
  @RequireOwnPermission(PERMISSIONS.emergencyCreateSelf)
  status(@Req() request: AuthorizedRequest, @Param() params: EmergencyIdParam) {
    return this.emergency.getStatus(
      params.bookingId,
      request.authorizationPrincipal!.userId,
    );
  }
}

@Controller('admin/emergency')
export class EmergencyAdminController {
  constructor(private readonly emergency: EmergencyService) {}

  @Get('dispatches')
  @RequirePermission(PERMISSIONS.emergencyDispatchManage)
  dispatches() {
    return this.emergency.listActiveDispatches();
  }
}
