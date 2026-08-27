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
    const userId = req.authorizationPrincipal!.userId;
    return this.messagesService.listMessages(bookingId, userId);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @RequireOwnPermission(PERMISSIONS.bookingChatSendSelf)
  async send(
    @Req() req: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Body() dto: SendBookingMessageBodyDto,
  ): Promise<BookingMessageDto> {
    const userId = req.authorizationPrincipal!.userId;
    return this.messagesService.sendMessage(bookingId, userId, dto);
  }
}
