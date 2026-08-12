import { Controller, Post, Patch, Get, Body, Param, Query, Req, UseInterceptors, HttpCode, HttpStatus } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { CreateBookingDto, UpdateBookingStatusDto, CancelBookingDto, BookingHistoryQueryDto } from './bookings.dto';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { Idempotent } from '../common/idempotency/idempotency.decorator';
import { IdempotencyInterceptor } from '../common/idempotency/idempotency.interceptor';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { BookingResponse } from '../../../shared/booking-lifecycle.types';

@Controller('api/v1/bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @RequireOwnPermission(PERMISSIONS.bookingCreateSelf)
  @UseInterceptors(IdempotencyInterceptor)
  @Idempotent()
  async create(
    @Req() req: AuthorizedRequest,
    @Body() dto: CreateBookingDto,
  ): Promise<BookingResponse> {
    const userId = req.authorizationPrincipal!.userId;
    const booking = await this.bookingsService.create(userId, dto);
    
    return {
      booking: booking,
    };
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingAccept)
  async accept(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
  ): Promise<BookingResponse> {
    const providerId = req.authorizationPrincipal!.userId;
    const booking = await this.bookingsService.acceptBooking(bookingId, providerId);
    
    return {
      booking,
    };
  }

  @Patch(':id/status')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingUpdateStatus)
  async updateStatus(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: UpdateBookingStatusDto,
  ): Promise<BookingResponse> {
    const providerId = req.authorizationPrincipal!.userId;
    const booking = await this.bookingsService.updateStatus(bookingId, providerId, dto.status);
    
    return {
      booking,
    };
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCancelSelf)
  async cancel(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: CancelBookingDto,
  ): Promise<BookingResponse> {
    const userId = req.authorizationPrincipal!.userId;
    const booking = await this.bookingsService.cancelBooking(bookingId, userId, dto.reason);
    
    return {
      booking,
    };
  }

  @Get()
  @RequireOwnPermission(PERMISSIONS.bookingHistoryReadSelf)
  async getHistory(
    @Req() req: AuthorizedRequest,
    @Query() query: BookingHistoryQueryDto,
  ) {
    const userId = req.authorizationPrincipal!.userId;
    const roles = req.authorizationPrincipal!.roles;
    const isProvider = roles.includes('verified_provider');
    const limit = query.limit ?? 10;
    const offset = query.offset ?? 0;
    
    const bookings = await this.bookingsService.getBookingHistory(userId, isProvider, limit, offset);
    return {
      bookings,
    };
  }
}
