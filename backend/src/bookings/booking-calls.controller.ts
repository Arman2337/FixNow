import {
  Controller,
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
import type {
  BookingCallDto,
  InitiateCallResponse,
} from '../../../shared/booking-call.types';

@Controller('bookings/:id/calls')
export class BookingCallsController {
  constructor(private readonly callsService: BookingCallsService) {}

  @Post('initiate')
  @HttpCode(HttpStatus.CREATED)
  @RequireOwnPermission(PERMISSIONS.bookingCallInitiateSelf)
  async initiate(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
  ): Promise<InitiateCallResponse> {
    const userId = req.authorizationPrincipal!.userId;
    return this.callsService.initiateCall(bookingId, userId);
  }

  @Post(':callId/answer')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCallManageSelf)
  async answer(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Param('callId') callId: string,
  ): Promise<BookingCallDto> {
    const userId = req.authorizationPrincipal!.userId;
    return this.callsService.answerCall(bookingId, callId, userId);
  }

  @Post(':callId/reject')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCallManageSelf)
  async reject(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Param('callId') callId: string,
  ): Promise<BookingCallDto> {
    const userId = req.authorizationPrincipal!.userId;
    return this.callsService.rejectCall(bookingId, callId, userId);
  }

  @Post(':callId/hangup')
  @HttpCode(HttpStatus.OK)
  @RequireOwnPermission(PERMISSIONS.bookingCallManageSelf)
  async hangup(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Param('callId') callId: string,
  ): Promise<BookingCallDto> {
    const userId = req.authorizationPrincipal!.userId;
    return this.callsService.hangupCall(bookingId, callId, userId);
  }
}
