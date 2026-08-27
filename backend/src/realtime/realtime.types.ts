import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';

export interface RealtimeClientMessage {
  readonly type: string;
  readonly requestId?: string;
  readonly accessToken?: string;
  readonly channel?: string;
  readonly resourceId?: string;
  readonly subscriptionId?: string;
  readonly afterSequence?: number;
  readonly online?: boolean;
  readonly bookingId?: string;
  readonly granted?: boolean;
  readonly noticeVersion?: string;
  readonly sequence?: number;
  readonly capturedAt?: string;
  readonly latitude?: number;
  readonly longitude?: number;
  readonly accuracyMeters?: number;
  readonly messageText?: string;
  readonly clientMessageId?: string;
}

export interface RealtimeConnectionState {
  address: string;
  principal?: AuthorizationPrincipal;
  accessToken?: string;
  authenticatedAt?: number;
  alive: boolean;
  messageWindowStartedAt: number;
  messageCount: number;
  subscriptions: Map<string, RealtimeSubscription>;
  authTimer?: NodeJS.Timeout;
}

export interface RealtimeSubscription {
  readonly id: string;
  readonly channel: 'account' | 'booking';
  readonly resourceId: string;
}
