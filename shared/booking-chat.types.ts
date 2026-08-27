export type ChatSenderRole = 'CUSTOMER' | 'PROVIDER';

export interface BookingMessageDto {
  readonly id: string;
  readonly bookingId: string;
  readonly senderUserId: string;
  readonly senderRole: ChatSenderRole;
  readonly clientMessageId?: string | null;
  readonly messageText: string;
  readonly readAt?: string | null;
  readonly createdAt: string;
}

export interface BookingMessagesListResponse {
  readonly messages: readonly BookingMessageDto[];
  readonly canSend: boolean;
}

export interface SendBookingMessageDto {
  readonly messageText: string;
  readonly clientMessageId?: string;
}
