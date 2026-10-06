import { Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { getHeapStatistics } from 'node:v8';
import { DataSource } from 'typeorm';
import { ReadinessState } from './readiness-state.service';
import {
  ObservabilityService,
  METRICS,
} from '../observability/observability.service';

/** One row on the dashboard: a label, a value, and whether it is a problem. */
export interface HealthFact {
  label: string;
  value: string;
  /** `false` marks a value an operator should act on, e.g. a failed ping. */
  ok: boolean;
}

export interface SystemHealthReport {
  /** `healthy` when every dependency answered and the instance is taking traffic. */
  status: 'healthy' | 'degraded';
  checkedAt: string;
  uptimeSeconds: number;
  uptimeHuman: string;
  memory: {
    heapUsedMb: number;
    heapTotalMb: number;
    rssMb: number;
    /** V8's own ceiling on the heap, which is not the process ceiling. */
    heapLimitMb: number;
  };
  database: {
    ok: boolean;
    latencyMs: number | null;
    detail: string;
  };
  cache: { ok: boolean; detail: string };
  environment: HealthFact[];
  metrics: HealthFact[];
}

const MB = 1024 * 1024;

/**
 * Collects what the rendered health dashboard shows.
 *
 * Separate from the controller that renders it, because the two have different
 * reasons to change: this file answers "what is the state of this instance" and
 * has no opinion about markup, and the renderer has no opinion about where a
 * number came from. It also means the facts are assertable without a DOM.
 *
 * Everything here is read from live process and connection state at call time.
 * Nothing is cached between calls, because a dashboard whose readings lag is
 * worse than no dashboard — a stale number looks exactly like a real one.
 */
@Injectable()
export class SystemHealthService {
  constructor(
    private readonly config: ConfigService,
    private readonly readiness: ReadinessState,
    private readonly observability: ObservabilityService,
    /**
     * Optional, and deliberately so.
     *
     * A hard dependency here would mean the health module cannot be assembled
     * without a `DataSource`, so the one component whose job is to report a
     * broken database would itself be the thing that fails to start. That is
     * exactly the failure terminus's own `TypeOrmHealthIndicator` avoids by
     * resolving its connection lazily and treating "absent" as "not up" rather
     * than as an error.
     *
     * It is also what keeps this module importable on its own:
     * `cache.module.spec.ts` builds the real `HealthModule` to test the Redis
     * watch's interaction with the drain state, and has no reason to stand up a
     * database to do it. With no connection the panel reports unavailable, which
     * is the truth in that context.
     */
    @Optional() private readonly dataSource?: DataSource,
  ) {}

  async collect(): Promise<SystemHealthReport> {
    const database = await this.checkDatabase();
    // `ReadinessState` is the authoritative degradation signal, not the
    // dependency probe: it already carries a drain (this process is shutting
    // down on purpose) and a Redis outage, and it distinguishes the two. The
    // database probe below is additive — it catches the case where Postgres is
    // gone but nothing has yet reported it as a dependency failure.
    const cache = this.readiness.state;
    const degraded = !this.readiness.isReady || !database.ok;
    const memory = process.memoryUsage();
    const uptimeSeconds = Math.floor(process.uptime());

    return {
      status: degraded ? 'degraded' : 'healthy',
      checkedAt: new Date().toISOString(),
      uptimeSeconds,
      uptimeHuman: humaniseUptime(uptimeSeconds),
      memory: {
        heapUsedMb: round(memory.heapUsed / MB),
        heapTotalMb: round(memory.heapTotal / MB),
        rssMb: round(memory.rss / MB),
        heapLimitMb: round(getHeapLimit() / MB),
      },
      database,
      cache: {
        // The readiness reason names the dependency and why, which is exactly
        // what an operator needs and is already free of anything sensitive.
        ok: this.readiness.isReady || !cache.reason?.startsWith('cache.'),
        detail: cache.reason ?? 'Redis is reachable.',
      },
      environment: this.environmentFacts(),
      metrics: this.metricFacts(),
    };
  }

  /**
   * A real round trip, timed.
   *
   * `SELECT 1` rather than the terminus ping so the number on the page is the
   * latency this instance is actually seeing, and so the dashboard does not
   * depend on a health indicator to report on health.
   */
  private async checkDatabase(): Promise<SystemHealthReport['database']> {
    if (!this.dataSource) {
      return {
        ok: false,
        latencyMs: null,
        detail: 'No database connection is configured in this process.',
      };
    }
    const startedAt = process.hrtime.bigint();
    try {
      await this.dataSource.query('SELECT 1');
      const latencyMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
      return {
        ok: true,
        latencyMs: round(latencyMs),
        detail: 'Postgres answered SELECT 1.',
      };
    } catch (error: unknown) {
      // The message is surfaced because an operator needs to know *why*, but it
      // is only ever rendered to an authenticated admin — this route is not
      // public. Still reduced to the error name: a driver message can embed the
      // connection string, and the connection string carries the password.
      const name = error instanceof Error ? error.name : 'Error';
      return {
        ok: false,
        latencyMs: null,
        detail: `Database check failed (${name}).`,
      };
    }
  }

  private environmentFacts(): HealthFact[] {
    const trustProxyHops = this.config.get<number>('TRUST_PROXY_HOPS');
    return [
      {
        label: 'NODE_ENV',
        value: this.config.get<string>('NODE_ENV') ?? 'development',
        ok: true,
      },
      {
        label: 'Port',
        value: String(this.config.get<number>('PORT') ?? 3000),
        ok: true,
      },
      {
        // Rendered, not hidden: this is the operator's own deployment and the
        // value is one number. It is on an admin-gated route precisely because
        // it is not something to publish.
        label: 'Trust proxy hops',
        value:
          typeof trustProxyHops === 'number'
            ? String(trustProxyHops)
            : 'unset (trusting no proxy)',
        // SEC-006: unset is the safe default, so it is not itself a fault — but
        // a production instance behind a proxy with this unset buckets the rate
        // limiter on the socket address, which is worth surfacing.
        ok: typeof trustProxyHops === 'number' && trustProxyHops > 0,
      },
      {
        label: 'Release',
        value: this.config.get<string>('APP_RELEASE') ?? 'unlabelled',
        ok: true,
      },
      {
        label: 'Draining',
        value: this.readiness.state.draining ? 'yes' : 'no',
        ok: !this.readiness.state.draining,
      },
    ];
  }

  private metricFacts(): HealthFact[] {
    const rendered = this.observability.render();
    const read = (name: string, suffix = ''): string => {
      const match = new RegExp(`^${name}${suffix} ([0-9.e+-]+)$`, 'm').exec(
        rendered,
      );
      return match ? match[1] : 'n/a';
    };
    return [
      {
        label: 'Outbox backlog',
        value: read(METRICS.outboxBacklog),
        // A backlog that only grows means a worker stopped. The threshold is a
        // judgement call, so it is a flag rather than a hard status.
        ok: Number(read(METRICS.outboxBacklog, '')) < 100,
      },
      {
        label: 'Bookings created',
        value: sumCounters(rendered, METRICS.bookingsCreated),
        ok: true,
      },
      {
        label: 'Dispatch offers',
        value: sumCounters(rendered, METRICS.dispatchOffers),
        ok: true,
      },
      {
        label: 'Realtime connections',
        value: read(METRICS.realtimeConnections),
        ok: true,
      },
      {
        label: 'HTTP 5xx',
        value: count5xx(rendered),
        // Non-zero is not automatically wrong during a deploy, but it is the
        // one number here an operator always wants to see.
        ok: count5xx(rendered) === '0',
      },
    ];
  }
}

/**
 * V8's heap ceiling for this process.
 *
 * Read from the `v8` module rather than `process.memoryUsage()`, which does not
 * report a limit — without it the dashboard can show a heap rising toward
 * nothing and an operator has no way to know how much room is left.
 */
function getHeapLimit(): number {
  return getHeapStatistics().heap_size_limit;
}

/** Sums every labelled sample of a counter — the registry renders one line each. */
function sumCounters(rendered: string, name: string): string {
  let total = 0;
  let found = false;
  for (const line of rendered.split('\n')) {
    if (!line.startsWith(name)) continue;
    const value = Number(line.slice(line.lastIndexOf(' ') + 1));
    if (Number.isFinite(value)) {
      total += value;
      found = true;
    }
  }
  return found ? String(total) : 'n/a';
}

/**
 * The 5xx count across every route.
 *
 * Summed from the rendered text rather than exposed as an API on
 * `ObservabilityService` because it is a presentation concern — the registry
 * deliberately does not accumulate per-status totals for a dashboard to read,
 * and adding a second read path over the same data would be a way for the two
 * to disagree.
 */
function count5xx(rendered: string): string {
  let total = 0;
  let found = false;
  for (const line of rendered.split('\n')) {
    if (!line.startsWith(METRICS.httpRequests)) continue;
    if (!line.includes('status="5xx"')) continue;
    const value = Number(line.slice(line.lastIndexOf(' ') + 1));
    if (Number.isFinite(value)) {
      total += value;
      found = true;
    }
  }
  return found ? String(total) : '0';
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * Uptime in the form an operator reads it at a glance.
 *
 * Hours are always shown, even when zero: "45s" and "45s" both describe a
 * process that restarted, whereas "0h 0m 45s" is visibly a young instance next
 * to a neighbour's "14h 22m".
 */
function humaniseUptime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return `${hours}h ${minutes}m ${secs}s`;
}
