import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { BookingMessagesService } from './booking-messages.service';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import type {
  BookingMessageDto,
  BookingMessagesListResponse,
} from '../../../shared/booking-chat.types';

export class SendBookingMessageBodyDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  messageText!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  clientMessageId?: string;
}

@Controller('bookings/:id/messages')
export class BookingMessagesController {
  constructor(private readonly messagesService: BookingMessagesService) {}

  @Get()
  @RequireOwnPermission(PERMISSIONS.bookingChatReadSelf)
  async list(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
  ): Promise<BookingMessagesListResponse> {
    const principal = req.authorizationPrincipal!;
    // SEC-002: discharged in the service — the response is a message list, not
    // the booking, so the controller has no party column to compare.
    return this.messagesService.listMessages(
      bookingId,
      principal.userId,
      principal,
    );
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @RequireOwnPermission(PERMISSIONS.bookingChatSendSelf)
  async send(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Body() dto: SendBookingMessageBodyDto,
  ): Promise<BookingMessageDto> {
    const principal = req.authorizationPrincipal!;
    return this.messagesService.sendMessage(
      bookingId,
      principal.userId,
      dto,
      principal,
    );
  }
}
