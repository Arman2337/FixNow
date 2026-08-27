import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Not, Repository } from 'typeorm';
import { Booking } from './domain/booking.entity';
import { BookingMessage } from './domain/booking-message.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type {
  BookingMessageDto,
  BookingMessagesListResponse,
  ChatSenderRole,
  SendBookingMessageDto,
} from '../../../shared/booking-chat.types';
import { BookingProjectionService } from '../realtime/booking-projection.service';
import { DomainNotificationService } from '../notifications/domain/domain-notification.service';

export function presentBookingMessage(
  entity: BookingMessage,
): BookingMessageDto {
  return {
    id: entity.id,
    bookingId: entity.bookingId,
    senderUserId: entity.senderUserId,
    senderRole: entity.senderRole,
    clientMessageId: entity.clientMessageId ?? null,
    messageText: entity.messageText,
    readAt: entity.readAt ? entity.readAt.toISOString() : null,
    createdAt: entity.createdAt.toISOString(),
  };
}

@Injectable()
export class BookingMessagesService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookingsRepo: Repository<Booking>,
    @InjectRepository(BookingMessage)
    private readonly messagesRepo: Repository<BookingMessage>,
    private readonly projections: BookingProjectionService,
    private readonly notifications: DomainNotificationService,
  ) {}

  async listMessages(
    bookingId: string,
    userId: string,
  ): Promise<BookingMessagesListResponse> {
    const booking = await this.bookingsRepo.findOne({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.customerId !== userId && booking.providerId !== userId) {
      throw new ForbiddenException(
        'Not authorized to access messages for this booking',
      );
    }

    const messages = await this.messagesRepo.find({
      where: { bookingId },
      order: { createdAt: 'ASC' },
    });

    // Mark unread messages sent by the other party as read
    await this.messagesRepo.update(
      {
        bookingId,
        senderUserId: Not(userId),
        readAt: IsNull(),
      },
      { readAt: new Date() },
    );

    const canSend = [
      BookingStatus.ASSIGNED,
      BookingStatus.EN_ROUTE,
      BookingStatus.IN_PROGRESS,
    ].includes(booking.status);

    return {
      messages: messages.map(presentBookingMessage),
      canSend,
    };
  }

  async sendMessage(
    bookingId: string,
    userId: string,
    dto: SendBookingMessageDto,
  ): Promise<BookingMessageDto> {
    const text = (dto.messageText ?? '').trim();
    if (!text) {
      throw new BadRequestException('Message text cannot be empty');
    }
    if (text.length > 2000) {
      throw new BadRequestException(
        'Message text exceeds 2000 characters limit',
      );
    }

    const booking = await this.bookingsRepo.findOne({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.customerId !== userId && booking.providerId !== userId) {
      throw new ForbiddenException(
        'Not authorized to message on this booking',
      );
    }

    const canSend = [
      BookingStatus.ASSIGNED,
      BookingStatus.EN_ROUTE,
      BookingStatus.IN_PROGRESS,
    ].includes(booking.status);
    if (!canSend) {
      throw new ConflictException(
        'Messaging is only allowed during active service (ASSIGNED, EN_ROUTE, IN_PROGRESS)',
      );
    }

    const senderRole: ChatSenderRole =
      booking.customerId === userId ? 'CUSTOMER' : 'PROVIDER';
    const recipientUserId =
      booking.customerId === userId ? booking.providerId : booking.customerId;
    const recipientAudience =
      booking.customerId === userId ? 'provider' : 'customer';

    // Idempotency check if clientMessageId is provided
    if (dto.clientMessageId) {
      const existing = await this.messagesRepo.findOne({
        where: {
          bookingId,
          senderUserId: userId,
          clientMessageId: dto.clientMessageId,
        },
      });
      if (existing) {
        return presentBookingMessage(existing);
      }
    }

    const message = this.messagesRepo.create({
      bookingId,
      senderUserId: userId,
      senderRole,
      clientMessageId: dto.clientMessageId ?? null,
      messageText: text,
      readAt: null,
    });

    const saved = await this.messagesRepo.save(message);
    const presented = presentBookingMessage(saved);

    // Broadcast to real-time WebSocket subscribers
    this.projections.publishChatMessage(bookingId, presented as unknown as Record<string, unknown>);

    // If recipient is not active on this booking channel, send push notification
    if (
      recipientUserId &&
      !this.projections.isSubscriberActive(bookingId, recipientUserId)
    ) {
      await this.notifications
        .notifyChatMessage(booking, recipientUserId, recipientAudience, saved.id)
        .catch(() => {});
    }

    return presented;
  }
}
