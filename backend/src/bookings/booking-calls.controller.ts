import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { BookingCallsService } from './booking-calls.service';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { assertOwnedByParty } from '../common/authorization/resource-ownership';
import type {
  BookingCallDto,
  InitiateCallResponse,
} from '../../../shared/booking-call.types';

@Controller('bookings/:id/calls')
export class BookingCallsController {
  constructor(private readonly callsService: BookingCallsService) {}

  @Get('active')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCallManageSelf)
  async getActive(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
  ): Promise<BookingCallDto | null> {
    const principal = req.authorizationPrincipal!;
    // SEC-002: may answer `null` (no live call), so the service discharges the
    // obligation against the booking it just proved is the caller's.
    return this.callsService.getActiveCall(
      bookingId,
      principal.userId,
      principal,
    );
  }

  @Post('initiate')
  @HttpCode(HttpStatus.CREATED)
  @RequireOwnPermission(PERMISSIONS.bookingCallInitiateSelf)
  async initiate(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
  ): Promise<InitiateCallResponse> {
    const principal = req.authorizationPrincipal!;
    return this.callsService.initiateCall(
      bookingId,
      principal.userId,
      principal,
    );
  }

  @Post(':callId/answer')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCallManageSelf)
  async answer(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Param('callId') callId: string,
  ): Promise<BookingCallDto> {
    const principal = req.authorizationPrincipal!;
    const call = await this.callsService.answerCall(
      bookingId,
      callId,
      principal.userId,
    );
    // SEC-002: the service loaded the call scoped to this booking and only the
    // callee may answer it. Its two endpoints are the booking's two parties.
    assertOwnedByParty(principal, call.calleeUserId, call.callerUserId);
    return call;
  }

  @Post(':callId/reject')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCallManageSelf)
  async reject(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Param('callId') callId: string,
  ): Promise<BookingCallDto> {
    const principal = req.authorizationPrincipal!;
    const call = await this.callsService.rejectCall(
      bookingId,
      callId,
      principal.userId,
    );
    assertOwnedByParty(principal, call.calleeUserId, call.callerUserId);
    return call;
  }

  @Post(':callId/hangup')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCallManageSelf)
  async hangup(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Param('callId') callId: string,
  ): Promise<BookingCallDto> {
    const principal = req.authorizationPrincipal!;
    const call = await this.callsService.hangupCall(
      bookingId,
      callId,
      principal.userId,
    );
    assertOwnedByParty(principal, call.calleeUserId, call.callerUserId);
    return call;
  }
}
