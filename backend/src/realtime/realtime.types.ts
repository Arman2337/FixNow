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
  readonly callId?: string;
  readonly data?: string;
}

export interface RealtimeConnectionState {
  address: string;
  principal?: AuthorizationPrincipal;
  accessToken?: string;
  authenticatedAt?: number;
  alive: boolean;
  messageWindowStartedAt: number;
  messageCount: number;
  voiceWindowStartedAt?: number;
  voiceMessageCount?: number;
  subscriptions: Map<string, RealtimeSubscription>;
  authTimer?: NodeJS.Timeout;
  /**
   * BUG-026. When this connection's session was last confirmed live against the
   * database.
   *
   * The access token was verified once, at `authenticate`. `auth_sessions` also
   * carries `expires_at` and `revoked_at`, and neither was ever re-read, so a
   * socket authenticated with a 15-minute token stayed open and kept receiving
   * booking frames, chat, and voice signalling for the life of the process -
   * which on a long-lived provider socket is days.
   *
   * Revoking a session, or a user being suspended, had no effect on a connection
   * that already existed. Every other request in the system re-reads the user
   * row and the full role set per request, so the realtime channel was the one
   * place a revocation did not apply.
   */
  sessionVerifiedAt?: number;
}

export interface RealtimeSubscription {
  readonly id: string;
  readonly channel: 'account' | 'booking';
  readonly resourceId: string;
}
