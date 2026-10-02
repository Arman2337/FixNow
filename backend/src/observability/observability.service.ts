import { Injectable, OnModuleDestroy } from '@nestjs/common';
import type { Request, Response, NextFunction } from 'express';
import { MetricRegistry } from './metric-registry';

/**
 * The metric names, declared once.
 *
 * Exported as constants rather than inlined strings because a typo in a metric
 * name is invisible: the registry throws on an undeclared name, so a misspelling
 * becomes an exception at the call site instead of a dashboard that silently
 * stops updating — which is the failure mode that makes a metric untrustworthy.
 */
export const METRICS = {
  /** How long booking creation takes, end to end, including the enqueue. */
  bookingCreateDuration: 'fixnow_booking_create_duration_seconds',
  /** How long a single provider-eligibility check takes. */
  matchingDuration: 'fixnow_matching_duration_seconds',
  /** Bookings created, by whether any provider was eligible. */
  bookingsCreated: 'fixnow_bookings_created_total',
  /** Dispatch offers sent, by outcome. The acceptance rate lives here. */
  dispatchOffers: 'fixnow_dispatch_offers_total',
  /** Unprocessed outbox rows. A number that grows is a worker that stopped. */
  outboxBacklog: 'fixnow_outbox_backlog',
  /** How long a push fan-out took. */
  notificationFanoutDuration: 'fixnow_notification_fanout_duration_seconds',
  /** Whether a dependency is currently usable, 1 or 0. */
  dependencyUp: 'fixnow_dependency_up',
  /** HTTP requests served, by route template, method and status class. */
  httpRequests: 'fixnow_http_requests_total',
  /** HTTP request duration, by route template. */
  httpDuration: 'fixnow_http_duration_seconds',
  /** Realtime connections currently open. */
  realtimeConnections: 'fixnow_realtime_connections',
} as const;

const DURATION_BUCKETS_SECONDS = [
  0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10,
] as const;
const MATCHING_BUCKETS_SECONDS = [
  0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5,
] as const;
const FANOUT_BUCKETS_SECONDS = [
  0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 30,
] as const;

/**
 * The registry, and the HTTP instrumentation that keeps it fed.
 *
 * Route *templates* rather than raw paths, because a raw path would make
 * `/bookings/<uuid>` its own time series — unbounded cardinality, which is the
 * standard way a metrics endpoint takes down the thing it is monitoring. Express
 * exposes the matched route on `req.route.path`, and that is what
 * `normaliseRoute` uses, with a fallback for routes that do not match (404s,
 * static files, the metrics endpoint itself).
 */
@Injectable()
export class ObservabilityService implements OnModuleDestroy {
  readonly registry = new MetricRegistry();

  private readonly httpDuration = this.registry.histogram(
    METRICS.httpDuration,
    'HTTP request duration in seconds, by route template and method.',
    DURATION_BUCKETS_SECONDS,
    ['route', 'method'],
  );
  private readonly bookingCreateDuration = this.registry.histogram(
    METRICS.bookingCreateDuration,
    'Booking creation duration in seconds, including the dispatch enqueue.',
    DURATION_BUCKETS_SECONDS,
    ['result'],
  );
  private readonly matchingDuration = this.registry.histogram(
    METRICS.matchingDuration,
    'Provider matching duration in seconds.',
    MATCHING_BUCKETS_SECONDS,
    ['stage'],
  );
  private readonly fanoutDuration = this.registry.histogram(
    METRICS.notificationFanoutDuration,
    'Push fan-out duration in seconds.',
    FANOUT_BUCKETS_SECONDS,
    ['channel'],
  );

  constructor() {
    this.registry.counter(METRICS.httpRequests, 'HTTP requests served.', [
      'route',
      'method',
      'status',
    ]);
    this.registry.counter(METRICS.bookingsCreated, 'Bookings created.', [
      'providers_available',
    ]);
    this.registry.counter(METRICS.dispatchOffers, 'Dispatch offers sent.', [
      'wave',
      'outcome',
    ]);
    this.registry.gauge(
      METRICS.outboxBacklog,
      'Outbox rows awaiting a worker. A value that only grows means a stopped worker.',
    );
    this.registry.gauge(
      METRICS.dependencyUp,
      'Whether a dependency is usable. 1 is up, 0 is down.',
      ['dependency'],
    );
    this.registry.gauge(
      METRICS.realtimeConnections,
      'Realtime websocket connections currently open.',
    );
  }

  /** Middleware factory. Registered globally in `main.ts`. */
  instrumentHttp() {
    return (req: Request, res: Response, next: NextFunction): void => {
      const startedAt = process.hrtime.bigint();
      res.on('finish', () => {
        const seconds = Number(process.hrtime.bigint() - startedAt) / 1e9;
        const route = normaliseRoute(req);
        const labels = {
          route,
          method: req.method,
          status: statusClass(res.statusCode),
        };
        this.httpDuration.observe(seconds, { route, method: req.method });
        this.registry.inc(METRICS.httpRequests, labels);
      });
      next();
    };
  }

  observeBookingCreate(
    seconds: number,
    result: 'created' | 'no_provider',
  ): void {
    this.bookingCreateDuration.observe(seconds, { result });
    this.registry.inc(METRICS.bookingsCreated, {
      providers_available: result === 'created' ? 'true' : 'false',
    });
  }

  observeMatching(seconds: number, stage = 'eligibility'): void {
    this.matchingDuration.observe(seconds, { stage });
  }

  observeFanout(seconds: number, channel = 'push'): void {
    this.fanoutDuration.observe(seconds, { channel });
  }

  countDispatchOffer(wave: string | number, outcome: string): void {
    this.registry.inc(METRICS.dispatchOffers, {
      wave: String(wave),
      outcome,
    });
  }

  setOutboxBacklog(rows: number): void {
    this.registry.set(METRICS.outboxBacklog, rows);
  }

  setDependencyUp(dependency: string, up: boolean): void {
    this.registry.set(METRICS.dependencyUp, up ? 1 : 0, { dependency });
  }

  setRealtimeConnections(count: number): void {
    this.registry.set(METRICS.realtimeConnections, count);
  }

  render(): string {
    return this.registry.render();
  }

  onModuleDestroy(): void {
    // Nothing to release: the registry holds no sockets or timers. Declared so
    // the lifecycle is explicit rather than accidental.
  }
}

/**
 * A bounded-cardinality route label.
 *
 * `req.route.path` is the matched template — `/bookings/:id` — which is exactly
 * what a dashboard wants. It is absent for 404s and for anything Express did not
 * route, so those collapse to a single `unmatched` series instead of producing
 * one series per attacker-supplied path.
 *
 * Express types `req.route` as `any`, so the shape is asserted here rather than
 * inherited — an unchecked `.path` off `any` would defeat the lint rule that
 * exists to catch exactly this.
 */
function normaliseRoute(req: Request): string {
  const route = (req as { route?: { path?: unknown } }).route?.path;
  if (typeof route === 'string' && route.length > 0) return route;
  if (Array.isArray(route)) {
    return route
      .filter((part): part is string => typeof part === 'string')
      .join('|');
  }
  return 'unmatched';
}

/**
 * Status *class*, not status code.
 *
 * `/health/liveness` returning 200 and another route returning 200 are the same
 * fact; a dashboard wants "how many 5xx", not a series per code.
 */
function statusClass(status: number): string {
  return `${Math.floor(status / 100)}xx`;
}
