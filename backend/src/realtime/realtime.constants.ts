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

export const REALTIME_CLOSE = {
  authenticationRequired: 4401,
  accessDenied: 4403,
  policyViolation: 4408,
  limitExceeded: 4429,
  dependencyUnavailable: 1013,
} as const;
