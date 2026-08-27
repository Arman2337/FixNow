import type { ChatSenderRole } from './booking-chat.types';

export type CallStatus =
  | 'INITIATED'
  | 'RINGING'
  | 'CONNECTED'
  | 'REJECTED'
  | 'MISSED'
  | 'ENDED'
  | 'FAILED';

export interface BookingCallDto {
  readonly id: string;
  readonly bookingId: string;
  readonly callerUserId: string;
  readonly callerRole: ChatSenderRole;
  readonly calleeUserId: string;
  readonly status: CallStatus;
  readonly startedAt: string;
  readonly connectedAt?: string | null;
  readonly endedAt?: string | null;
  readonly durationSeconds?: number | null;
}

export interface InitiateCallResponse {
  readonly call: BookingCallDto;
}
