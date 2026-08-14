import {
  Controller,
  Post,
  Patch,
  Get,
  Body,
  Param,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  Headers,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';
import {
  CreateBookingDto,
  UpdateBookingStatusDto,
  CancelBookingDto,
  BookingHistoryQueryDto,
  AcceptBookingDto,
  AvailableBookingQueryDto,
} from './bookings.dto';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  BookingHistoryResponse,
  BookingResponse,
  ProviderBookingRequestResponse,
} from '../../../shared/booking-lifecycle.types';
import {
  presentBooking,
  presentProviderBookingRequest,
} from './booking.presenter';

@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @RequireOwnPermission(PERMISSIONS.bookingCreateSelf)
  async create(
    @Req() req: AuthorizedRequest,
    @Body() dto: CreateBookingDto,
    @Headers('idempotency-key') idempotencyKey: string,
  ): Promise<BookingResponse> {
    const userId = req.authorizationPrincipal!.userId;
    const booking = await this.bookingsService.create(
      userId,
      dto,
      idempotencyKey,
    );

    return {
      booking: presentBooking(booking),
    };
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingAccept)
  async accept(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: AcceptBookingDto,
  ): Promise<BookingResponse> {
    const providerId = req.authorizationPrincipal!.userId;
    const booking = await this.bookingsService.acceptBooking(
      bookingId,
      providerId,
      dto.expectedVersion,
    );

    return {
      booking: presentBooking(booking),
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
    const booking = await this.bookingsService.updateStatus(
      bookingId,
      providerId,
      dto.status,
      dto.expectedVersion,
    );

    return {
      booking: presentBooking(booking),
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
    const booking = await this.bookingsService.cancelBooking(
      bookingId,
      userId,
      dto.reason,
      dto.expectedVersion,
    );

    return {
      booking: presentBooking(booking),
    };
  }

  @Get()
  @RequireOwnPermission(PERMISSIONS.bookingHistoryReadSelf)
  async getHistory(
    @Req() req: AuthorizedRequest,
    @Query() query: BookingHistoryQueryDto,
  ): Promise<BookingHistoryResponse> {
    const userId = req.authorizationPrincipal!.userId;
    const limit = query.limit ?? 10;

    const page = await this.bookingsService.getBookingHistory(
      userId,
      limit,
      query.cursor,
    );
    return {
      bookings: page.bookings.map(presentBooking),
      nextCursor: page.nextCursor,
    };
  }

  @Get('available')
  @RequireOwnPermission(PERMISSIONS.bookingAvailableRead)
  async getAvailableRequests(
    @Req() req: AuthorizedRequest,
    @Query() query: AvailableBookingQueryDto,
  ): Promise<ProviderBookingRequestResponse> {
    const providerId = req.authorizationPrincipal!.userId;
    const page = await this.bookingsService.getAvailableRequests(
      providerId,
      query.limit,
    );
    return {
      bookings: page.bookings.map(({ booking, distanceKm }) =>
        presentProviderBookingRequest(booking, distanceKm),
      ),
    };
  }
}
