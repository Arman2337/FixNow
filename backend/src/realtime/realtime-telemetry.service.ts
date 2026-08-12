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
  | 'dependency.failure';

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
