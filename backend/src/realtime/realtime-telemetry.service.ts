import { Injectable } from '@nestjs/common';

export type RealtimeMetric =
  | 'connections.accepted'
  | 'connections.denied'
  | 'connections.closed'
  | 'authentication.allowed'
  | 'authentication.denied'
  | 'subscriptions.allowed'
  | 'subscriptions.denied'
  | 'messages.invalid'
  | 'limits.exceeded'
  | 'heartbeat.timeout'
  | 'location.denied'
  | 'dependency.failure'
  /**
   * BUG-026. `session.revoked` is a real denial - the session behind a live
   * socket stopped being valid, and the socket was closed. It is worth its own
   * counter because it should be zero in normal operation: a non-zero rate means
   * sessions are being revoked faster than clients can refresh, which is a
   * client problem rather than a platform one.
   *
   * `session.revalidation.deferred` is the opposite and is expected to be
   * non-zero: it counts checks that could not reach a conclusion, almost always
   * because the database was briefly unavailable. A sustained non-zero rate is
   * the signal that revocation is no longer being enforced promptly, which is
   * precisely the failure this mechanism was added to prevent.
   */
  | 'session.revoked'
  | 'session.revalidation.deferred';

@Injectable()
export class RealtimeTelemetryService {
  private readonly counters = new Map<RealtimeMetric, number>();

  increment(metric: RealtimeMetric): void {
    this.counters.set(metric, (this.counters.get(metric) ?? 0) + 1);
  }

  snapshot(): Readonly<Record<string, number>> {
    return Object.fromEntries(this.counters);
  }
}
