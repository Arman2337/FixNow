export const REALTIME_PATH = '/realtime';
export const REALTIME_PROTOCOL_VERSION = 1;
export const REALTIME_MAX_PAYLOAD_BYTES = 16 * 1024;
export const REALTIME_AUTH_TIMEOUT_MS = 5_000;
export const REALTIME_HEARTBEAT_INTERVAL_MS = 30_000;
export const REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL = 3;
export const REALTIME_MAX_PENDING_CONNECTIONS_PER_ADDRESS = 10;
export const REALTIME_MAX_SUBSCRIPTIONS = 10;
export const REALTIME_MESSAGE_WINDOW_MS = 60_000;
export const REALTIME_MAX_MESSAGES_PER_WINDOW = 30;
export const REALTIME_MAX_VOICE_FRAMES_PER_WINDOW = 3600;

/**
 * BUG-026. How long a socket's session may go unconfirmed against the database.
 *
 * The access token is short-lived (minutes), but the socket it authenticated is
 * not: a provider's stays open across a whole shift, and `auth_sessions` also
 * carries `revoked_at` and `expires_at` that were never re-read. So a session
 * revoked, or a user suspended, had no effect on a connection that already
 * existed - and the realtime channel carries booking state, chat and voice
 * signalling, so that is a live data-exfiltration path rather than a stale
 * display.
 *
 * Sixty seconds is a deliberate trade. It is well inside the window in which a
 * revocation would otherwise go unnoticed, it is short enough that the extra
 * query per connection per minute is negligible next to the frames being sent,
 * and it is not so short that a busy socket turns into a query storm. The check
 * is per-connection rather than per-broadcast precisely so that cost is bounded
 * this way.
 */
export const REALTIME_SESSION_REVALIDATION_MS = 60_000;

/**
 * PERF-005. How long a client waits for a `pong` before treating its socket as
 * dead and reconnecting.
 *
 * A suspended mobile app cannot answer the protocol-level ping this gateway
 * sends every {@link REALTIME_HEARTBEAT_INTERVAL_MS}, because the Dart isolate
 * is frozen. The gateway therefore terminates the socket after two missed
 * heartbeats - correctly - but the client is asleep and does not observe the
 * close until it wakes up, by which point it believes it is still connected and
 * renders whatever it last received. On resume it has no signal at all: no frame
 * arrives, no error fires, and `isConnected` stays true.
 *
 * That is why this needs an application-level probe rather than a shorter
 * timeout. The protocol ping answers "is the network path alive", which is
 * exactly the question that cannot distinguish a frozen client from a healthy
 * one. A `ping` the client sends after waking answers "is the server still
 * serving this session", which is the question that matters.
 *
 * Five seconds is generous for a round trip that involves no database work, and
 * short enough that a provider opening the app does not stare at a stale
 * dashboard wondering whether to pull to refresh.
 */
export const REALTIME_PONG_TIMEOUT_MS = 5_000;

export const REALTIME_CLOSE = {
  authenticationRequired: 4401,
  accessDenied: 4403,
  policyViolation: 4408,
  limitExceeded: 4429,
  /** BUG-026: the session behind this socket is no longer valid. */
  sessionRevoked: 4403,
  dependencyUnavailable: 1013,
} as const;
