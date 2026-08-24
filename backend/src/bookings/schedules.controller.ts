import { Body, Controller, Get, Param, Patch, Post, Req } from '@nestjs/common';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { presentBooking } from './booking.presenter';
import { CreateScheduleDto, UpdateScheduleStatusDto } from './schedules.dto';
import { SchedulesService } from './schedules.service';
import type { RecurringScheduleContract } from '../../../shared/recurring.types';
import type { BookingContract } from '../../../shared/booking-lifecycle.types';

/**
 * FN-112 recurring schedules. Occurrences are never booked silently: each
 * becomes a booking only through the explicit confirm endpoint. Every route
 * is customer-scoped: the schedule owner always comes from the access token.
 */
@Controller('bookings/schedules')
export class SchedulesController {
  constructor(private readonly schedules: SchedulesService) {}

  @Post()
  @RequireOwnPermission(PERMISSIONS.bookingScheduleManageSelf)
  async create(
    @Req() req: AuthorizedRequest,
    @Body() dto: CreateScheduleDto,
  ): Promise<RecurringScheduleContract> {
    return this.schedules.create(req.authorizationPrincipal!.userId, dto);
  }

  @Get()
  @RequireOwnPermission(PERMISSIONS.bookingScheduleManageSelf)
  async listSelf(
    @Req() req: AuthorizedRequest,
  ): Promise<RecurringScheduleContract[]> {
    return this.schedules.listSelf(req.authorizationPrincipal!.userId);
  }

  @Patch(':id/status')
  @RequireOwnPermission(PERMISSIONS.bookingScheduleManageSelf)
  async updateStatus(
    @Param('id') id: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: UpdateScheduleStatusDto,
  ): Promise<RecurringScheduleContract> {
    return this.schedules.updateStatus(
      req.authorizationPrincipal!.userId,
      id,
      dto.action,
    );
  }

  @Post(':id/confirm')
  @RequireOwnPermission(PERMISSIONS.bookingScheduleManageSelf)
  async confirmOccurrence(
    @Param('id') id: string,
    @Req() req: AuthorizedRequest,
  ): Promise<{
    booking: BookingContract;
    schedule: RecurringScheduleContract;
  }> {
    const result = await this.schedules.confirmOccurrence(
      req.authorizationPrincipal!.userId,
      id,
    );
    return {
      booking: presentBooking(result.booking),
      schedule: result.schedule,
    };
  }
}
