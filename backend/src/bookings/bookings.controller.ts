import {
  Controller,
  Post,
  Patch,
  Put,
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
  UpdateBookingItemsDto,
  CancelBookingDto,
  RescheduleBookingDto,
  BookingHistoryQueryDto,
  AcceptBookingDto,
  VerifyServiceStartOtpDto,
  AvailableBookingQueryDto,
  UpdateBookingLineItemsDto,
} from './bookings.dto';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  assertAssignedResource,
  assertNoResourceToProve,
  assertOwnedByParty,
  assertOwnedResource,
} from '../common/authorization/resource-ownership';
import {
  BookingHistoryResponse,
  BookingCreationResponse,
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
  ): Promise<BookingCreationResponse> {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    // BUG-014: the eligible count travels with the booking. `status: REQUESTED`
    // on its own cannot be distinguished from a search that will never resolve,
    // and "nobody is available" is the most common answer on day one in a new
    // city.
    const result = await this.bookingsService.create(
      userId,
      dto,
      idempotencyKey,
    );

    // SEC-002: the persisted booking's own `customerId` proves the caller is
    // the customer the booking was raised for.
    assertOwnedResource(
      principal,
      result.booking.customerId,
      'booking.customerId',
    );

    return {
      booking: presentBooking(result.booking),
      eligibleProviderCount: result.eligibleProviderCount,
      noProviderAvailable: result.noProviderAvailable,
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
    const principal = req.authorizationPrincipal!;
    const providerId = principal.userId;
    const booking = await this.bookingsService.acceptBooking(
      bookingId,
      providerId,
      dto.expectedVersion,
    );

    // SEC-002: only the provider the booking is now assigned to may accept, so
    // this is the assignment column rather than "either party".
    assertAssignedResource(principal, booking.providerId, 'booking.providerId');

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
    const principal = req.authorizationPrincipal!;
    const providerId = principal.userId;
    const booking = await this.bookingsService.updateStatus(
      bookingId,
      providerId,
      dto.status,
      dto.expectedVersion,
    );

    assertAssignedResource(principal, booking.providerId, 'booking.providerId');

    return {
      booking: presentBooking(booking),
    };
  }

  @Patch(':id/items')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingManageItems)
  async updateItems(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: UpdateBookingItemsDto,
  ): Promise<BookingResponse> {
    const principal = req.authorizationPrincipal!;
    const providerId = principal.userId;
    const booking = await this.bookingsService.updateBookingItems(
      bookingId,
      providerId,
      dto,
    );
    assertAssignedResource(principal, booking.providerId, 'booking.providerId');
    return { booking: presentBooking(booking) };
  }

  @Put(':id/line-items')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingManageItems)
  async updateLineItems(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: UpdateBookingLineItemsDto,
  ): Promise<BookingResponse> {
    const principal = req.authorizationPrincipal!;
    const providerId = principal.userId;
    const booking = await this.bookingsService.updateBookingLineItems(
      bookingId,
      providerId,
      dto.lineItems,
      dto.expectedVersion,
    );

    assertAssignedResource(principal, booking.providerId, 'booking.providerId');

    return {
      booking: presentBooking(booking),
    };
  }

  @Post(':id/service-start-otp')
  @RequireOwnPermission(PERMISSIONS.bookingServiceStartOtp)
  async serviceStartOtp(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
  ): Promise<{ otp: string }> {
    // The service discloses a one-time code, so the caller must be the
    // booking's customer. It returns only the code, so the obligation is
    // discharged inside the service where the booking is loaded.
    return this.bookingsService.getServiceStartOtp(
      bookingId,
      req.authorizationPrincipal!,
    );
  }

  @Post(':id/start-service')
  @RequireOwnPermission(PERMISSIONS.bookingUpdateStatus)
  async startService(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: VerifyServiceStartOtpDto,
  ): Promise<BookingResponse> {
    const principal = req.authorizationPrincipal!;
    const booking = await this.bookingsService.verifyOtpAndStartService(
      bookingId,
      principal.userId,
      dto.otp,
      dto.expectedVersion,
    );
    assertAssignedResource(principal, booking.providerId, 'booking.providerId');
    return { booking: presentBooking(booking) };
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCancelSelf)
  async cancel(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: CancelBookingDto,
  ): Promise<BookingResponse> {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    const booking = await this.bookingsService.cancelBooking(
      bookingId,
      userId,
      dto.reason,
      dto.expectedVersion,
      // BUG-020. A provider abandoning a job they have started sends a reason
      // code; the service requires one and records it with the free text, so
      // support can tell a re-dispatch from a dispute without parsing prose.
      dto.abandonmentReason,
    );

    // Either the customer or the assigned provider may cancel their own job.
    assertOwnedByParty(principal, booking.customerId, booking.providerId);

    return {
      booking: presentBooking(booking),
    };
  }

  @Post(':id/reschedule')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCancelSelf)
  async reschedule(
    @Param('id') bookingId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: RescheduleBookingDto,
  ): Promise<BookingResponse> {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    const booking = await this.bookingsService.rescheduleBooking(
      bookingId,
      userId,
      dto.newScheduledAt,
      dto.expectedVersion,
      dto.reason,
    );

    assertOwnedByParty(principal, booking.customerId, booking.providerId);

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
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    // SEC-002: the caller reads their own history, selected by the principal's
    // own id inside the query. No caller-named resource is involved.
    assertNoResourceToProve(principal);
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
    const principal = req.authorizationPrincipal!;
    // SEC-002: an open job board, deliberately not caller-owned. What is
    // caller-scoped is the *offer*, which the service derives from the
    // principal's own id; no offered resource belongs to the caller.
    assertNoResourceToProve(principal);
    const providerId = principal.userId;
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

  /// Declared after the static routes so `available` is not captured as an id.
  @Get(':id')
  @RequireOwnPermission(PERMISSIONS.bookingHistoryReadSelf)
  async getBooking(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
  ): Promise<BookingResponse> {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    const booking = await this.bookingsService.getBookingForUser(
      bookingId,
      userId,
    );
    assertOwnedByParty(principal, booking.customerId, booking.providerId);
    return {
      booking: presentBooking(booking),
    };
  }
}
