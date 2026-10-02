import { randomUUID } from 'node:crypto';

/**
 * The response header the client quotes in a support ticket. The inbound
 * header name is the same, which is conventional: a proxy stamps its trace id
 * on the way in, and the id is echoed under the same name on the way out.
 */
export const CORRELATION_HEADER = 'x-request-id';

/**
 * A correlation id we are willing to believe.
 *
 * The value is attacker-controlled on any request that did not come through
 * our own proxy, and it lands in log output. Newlines would let a caller forge
 * log lines, and an unbounded string would let them bloat the log. So the
 * inbound value is accepted only if it is short and entirely unambiguous
 * characters, and is dropped otherwise.
 *
 * This is stricter than a UUID check on purpose: some ingress (nginx, Cloud
 * Run, a mesh sidecar) stamps hex trace ids rather than UUIDs, and rejecting
 * those would break trace continuation across a deployment for no security
 * gain once the character set is constrained.
 */
const SAFE_REQUEST_ID = /^[A-Za-z0-9._-]{8,64}$/;

/**
 * The id for a request: the caller's if it is safe, otherwise a fresh UUID.
 */
export function resolveRequestId(inbound: unknown): string {
  const candidate: unknown = Array.isArray(inbound) ? inbound[0] : inbound;
  if (typeof candidate === 'string' && SAFE_REQUEST_ID.test(candidate)) {
    return candidate;
  }
  return randomUUID();
}
