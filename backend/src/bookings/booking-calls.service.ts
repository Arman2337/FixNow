import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Booking } from './domain/booking.entity';
import { BookingCall } from './domain/booking-call.entity';
import { BookingMessage } from './domain/booking-message.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type {
  BookingCallDto,
  CallStatus,
  InitiateCallResponse,
} from '../../../shared/booking-call.types';
import type { ChatSenderRole } from '../../../shared/booking-chat.types';
import { BookingProjectionService } from '../realtime/booking-projection.service';
import { presentBookingMessage } from './booking-messages.service';

export function presentBookingCall(entity: BookingCall): BookingCallDto {
  return {
    id: entity.id,
    bookingId: entity.bookingId,
    callerUserId: entity.callerUserId,
    callerRole: entity.callerRole,
    calleeUserId: entity.calleeUserId,
    status: entity.status,
    startedAt: entity.startedAt.toISOString(),
    connectedAt: entity.connectedAt ? entity.connectedAt.toISOString() : null,
    endedAt: entity.endedAt ? entity.endedAt.toISOString() : null,
    durationSeconds: entity.durationSeconds,
  };
}

@Injectable()
export class BookingCallsService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookingsRepo: Repository<Booking>,
    @InjectRepository(BookingCall)
    private readonly callsRepo: Repository<BookingCall>,
    @InjectRepository(BookingMessage)
    private readonly messagesRepo: Repository<BookingMessage>,
    private readonly projections: BookingProjectionService,
  ) {}

  async initiateCall(
    bookingId: string,
    callerUserId: string,
  ): Promise<InitiateCallResponse> {
    const booking = await this.bookingsRepo.findOne({
      where: { id: bookingId },
    });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    if (
      booking.customerId !== callerUserId &&
      booking.providerId !== callerUserId
    ) {
      throw new ForbiddenException('Not authorized to call on this booking');
    }

    // Calling allowed strictly during assigned / en route transit states
    const allowed = [BookingStatus.ASSIGNED, BookingStatus.EN_ROUTE].includes(
      booking.status,
    );
    if (!allowed) {
      throw new ConflictException(
        'In-app audio calling is only allowed while provider is assigned or en route',
      );
    }

    const callerRole: ChatSenderRole =
      booking.customerId === callerUserId ? 'CUSTOMER' : 'PROVIDER';
    const calleeUserId =
      booking.customerId === callerUserId
        ? booking.providerId
        : booking.customerId;

    if (!calleeUserId) {
      throw new BadRequestException('Recipient is not assigned yet');
    }

    const call = this.callsRepo.create({
      bookingId,
      callerUserId,
      callerRole,
      calleeUserId,
      status: 'RINGING',
      connectedAt: null,
      endedAt: null,
      durationSeconds: null,
    });

    const saved = await this.callsRepo.save(call);
    const presented = presentBookingCall(saved);

    // Broadcast incoming call signal to subscribed sockets
    this.projections.publishCallSignal(
      bookingId,
      'call.incoming.v1',
      presented as unknown as Record<string, unknown>,
    );

    return { call: presented };
  }

  async answerCall(
    bookingId: string,
    callId: string,
    calleeUserId: string,
  ): Promise<BookingCallDto> {
    const call = await this.callsRepo.findOne({
      where: { id: callId, bookingId },
    });
    if (!call) {
      throw new NotFoundException('Call session not found');
    }

    if (call.calleeUserId !== calleeUserId) {
      throw new ForbiddenException('Only the callee can answer this call');
    }

    if (call.status !== 'INITIATED' && call.status !== 'RINGING') {
      throw new ConflictException(
        `Cannot answer call in status ${call.status}`,
      );
    }

    call.status = 'CONNECTED';
    call.connectedAt = new Date();

    const saved = await this.callsRepo.save(call);
    const presented = presentBookingCall(saved);

    this.projections.publishCallSignal(
      bookingId,
      'call.answered.v1',
      presented as unknown as Record<string, unknown>,
    );

    return presented;
  }

  async rejectCall(
    bookingId: string,
    callId: string,
    userId: string,
  ): Promise<BookingCallDto> {
    const call = await this.callsRepo.findOne({
      where: { id: callId, bookingId },
    });
    if (!call) {
      throw new NotFoundException('Call session not found');
    }

    if (call.calleeUserId !== userId && call.callerUserId !== userId) {
      throw new ForbiddenException('Not authorized for this call session');
    }

    if (call.status === 'ENDED' || call.status === 'REJECTED') {
      return presentBookingCall(call);
    }

    call.status = 'REJECTED';
    call.endedAt = new Date();
    call.durationSeconds = 0;

    const saved = await this.callsRepo.save(call);
    const presented = presentBookingCall(saved);

    this.projections.publishCallSignal(
      bookingId,
      'call.rejected.v1',
      presented as unknown as Record<string, unknown>,
    );

    // Append honest call record to chat messages
    const message = await this.messagesRepo.save(
      this.messagesRepo.create({
        bookingId,
        senderUserId: call.callerUserId,
        senderRole: call.callerRole,
        messageText: '📞 Missed in-app audio call',
        readAt: null,
      }),
    );
    this.projections.publishChatMessage(
      bookingId,
      presentBookingMessage(message) as unknown as Record<string, unknown>,
    );

    return presented;
  }

  async hangupCall(
    bookingId: string,
    callId: string,
    userId: string,
  ): Promise<BookingCallDto> {
    const call = await this.callsRepo.findOne({
      where: { id: callId, bookingId },
    });
    if (!call) {
      throw new NotFoundException('Call session not found');
    }

    if (call.calleeUserId !== userId && call.callerUserId !== userId) {
      throw new ForbiddenException('Not authorized for this call session');
    }

    if (call.status === 'ENDED') {
      return presentBookingCall(call);
    }

    call.endedAt = new Date();
    if (call.connectedAt) {
      call.status = 'ENDED';
      call.durationSeconds = Math.max(
        0,
        Math.round(
          (call.endedAt.getTime() - call.connectedAt.getTime()) / 1000,
        ),
      );
    } else {
      call.status = 'MISSED';
      call.durationSeconds = 0;
    }

    const saved = await this.callsRepo.save(call);
    const presented = presentBookingCall(saved);

    this.projections.publishCallSignal(
      bookingId,
      'call.ended.v1',
      presented as unknown as Record<string, unknown>,
    );

    // Append formatted summary message in chat
    const durationSeconds = call.durationSeconds ?? 0;
    let summaryText: string;
    if (durationSeconds > 0) {
      const minutes = Math.floor(durationSeconds / 60);
      const seconds = durationSeconds % 60;
      const durationFormatted =
        minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;
      summaryText = `📞 In-app audio call ended • ${durationFormatted}`;
    } else {
      summaryText = '📞 In-app audio call ended (unanswered)';
    }

    const message = await this.messagesRepo.save(
      this.messagesRepo.create({
        bookingId,
        senderUserId: call.callerUserId,
        senderRole: call.callerRole,
        messageText: summaryText,
        readAt: null,
      }),
    );
    this.projections.publishChatMessage(
      bookingId,
      presentBookingMessage(message) as unknown as Record<string, unknown>,
    );

    return presented;
  }
}
