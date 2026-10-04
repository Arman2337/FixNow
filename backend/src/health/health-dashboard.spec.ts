import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import { HealthCheckService } from '@nestjs/terminus';
import { ReadinessState } from './readiness-state.service';
import { SystemHealthService } from './system-health.service';
import { renderHealthDashboard } from './health-dashboard';
import { ObservabilityService } from '../observability/observability.service';

function buildReport(overrides: Record<string, unknown> = {}) {
  return {
    status: 'healthy' as const,
    checkedAt: '2026-10-04T12:00:00.000Z',
    uptimeSeconds: 5325,
    uptimeHuman: '1h 28m 45s',
    memory: {
      heapUsedMb: 48.2,
      heapTotalMb: 96.5,
      rssMb: 210.7,
      heapLimitMb: 4096,
    },
    database: {
      ok: true,
      latencyMs: 3.42,
      detail: 'Postgres answered SELECT 1.',
    },
    cache: { ok: true, detail: 'Redis is reachable.' },
    environment: [
      { label: 'NODE_ENV', value: 'production', ok: true },
      { label: 'Port', value: '3300', ok: true },
    ],
    metrics: [{ label: 'Outbox backlog', value: '0', ok: true }],
    ...overrides,
  } as Parameters<typeof renderHealthDashboard>[0];
}

describe('renderHealthDashboard', () => {
  it('renders the sections an operator needs without a JSON client', () => {
    const html = renderHealthDashboard(buildReport());

    expect(html).toContain('<!DOCTYPE html>');
    expect(html).toContain('FixNow health dashboard');
    // Each of the requested panels.
    expect(html).toContain('Healthy');
    expect(html).toContain('1h 28m 45s');
    expect(html).toContain('48.2 MB / 96.5 MB');
    expect(html).toContain('210.7 MB');
    expect(html).toContain('4096 MB');
    // A healthy database shows the measured latency rather than the prose
    // detail — the number is what an operator is looking for.
    expect(html).toContain('connected · 3.42 ms');
    expect(html).toContain('Redis is reachable.');
    expect(html).toContain('production');
    expect(html).toContain('3300');
    expect(html).toContain('Outbox backlog');
  });

  it('reports a degraded instance as degraded', () => {
    const html = renderHealthDashboard(
      buildReport({
        status: 'degraded',
        database: {
          ok: false,
          latencyMs: null,
          detail: 'Database check failed (Error).',
        },
      }),
    );

    expect(html).toContain('Degraded');
    expect(html).not.toContain('>Healthy<');
    expect(html).toContain('Database check failed (Error).');
  });

  it('offers the auto-refresh control at 10s and 30s', () => {
    const html = renderHealthDashboard(buildReport());

    expect(html).toContain('id="auto"');
    expect(html).toContain('Auto-refresh');
    expect(html).toContain('value="10000"');
    expect(html).toContain('value="30000"');
  });

  // Every value on the page is interpolated, and most are process numbers — but
  // the dependency `detail` carries an error name. An escaping function that is
  // only correct for today's values is how a reflected XSS arrives later with an
  // innocent change to what is displayed.
  it('escapes values rather than interpolating them as markup', () => {
    const html = renderHealthDashboard(
      buildReport({
        cache: {
          ok: false,
          detail: '<img src=x onerror="alert(1)">',
        },
      }),
    );

    expect(html).not.toContain('<img src=x');
    expect(html).toContain('&lt;img src=x');
  });

  it('marks a failing fact so it is visually distinct', () => {
    const html = renderHealthDashboard(
      buildReport({
        environment: [
          {
            label: 'Trust proxy hops',
            value: 'unset (trusting no proxy)',
            ok: false,
          },
        ],
      }),
    );

    expect(html).toMatch(
      /<tr class="bad">\s*<th scope="row">Trust proxy hops<\/th>/,
    );
  });
});

describe('SystemHealthService', () => {
  const query = jest.fn();
  const observability = { render: jest.fn().mockReturnValue('') };
  let readiness: ReadinessState;

  const build = async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        SystemHealthService,
        ReadinessState,
        { provide: ConfigService, useValue: { get: () => undefined } },
        { provide: ObservabilityService, useValue: observability },
        { provide: DataSource, useValue: { query } },
        { provide: HealthCheckService, useValue: {} },
      ],
    }).compile();
    // The injected instance, not a fresh one. `ReadinessState` holds the drain
    // flag, so draining a separate instance leaves the service's own copy
    // untouched and the degradation never becomes visible to `collect()`.
    readiness = moduleRef.get(ReadinessState);
    return moduleRef.get(SystemHealthService);
  };

  beforeEach(() => {
    query.mockReset().mockResolvedValue([{ '?column?': 1 }]);
    observability.render.mockReturnValue('');
  });

  it('reports healthy when the database answers and the instance is ready', async () => {
    const service = await build();
    const report = await service.collect();

    expect(report.status).toBe('healthy');
    expect(report.database.ok).toBe(true);
    expect(typeof report.database.latencyMs).toBe('number');
  });

  it('degrades when the database does not answer', async () => {
    query.mockRejectedValue(new Error('connection refused'));
    const service = await build();
    const report = await service.collect();

    expect(report.status).toBe('degraded');
    expect(report.database.ok).toBe(false);
  });

  // A driver message can embed the connection string, and the connection string
  // carries the password. The error's *name* is what an operator needs; the
  // message is not.
  it('does not put a raw driver message in the report', async () => {
    query.mockRejectedValue(
      new Error(
        'connect ECONNREFUSED postgresql://fixnow:hunter2@db.internal:5432/fixnow',
      ),
    );
    const service = await build();
    const report = await service.collect();

    expect(report.database.detail).not.toContain('hunter2');
    expect(report.database.detail).toContain('Error');
  });

  it('degrades when the instance is draining', async () => {
    const service = await build();
    // After `build()`, so this is the same instance the service holds. Draining
    // first would flag a `ReadinessState` the service never sees.
    readiness.beginDraining('SIGTERM');

    const report = await service.collect();

    expect(report.status).toBe('degraded');
  });

  it('reports uptime in a human-readable form', async () => {
    const service = await build();
    const report = await service.collect();

    // Hours are always present, so a freshly restarted instance is visibly
    // younger than its neighbour next to a long uptime.
    expect(report.uptimeHuman).toMatch(/^\d+h \d+m \d+s$/);
  });

  it('counts 5xx responses across every route', async () => {
    observability.render.mockReturnValue(
      [
        'fixnow_http_requests_total{route="/a",method="GET",status="2xx"} 10',
        'fixnow_http_requests_total{route="/b",method="GET",status="5xx"} 3',
        'fixnow_http_requests_total{route="/c",method="POST",status="5xx"} 1',
        'fixnow_http_requests_total{route="/d",method="GET",status="4xx"} 2',
      ].join('\n'),
    );
    const service = await build();
    const report = await service.collect();

    const row = report.metrics.find((m) => m.label === 'HTTP 5xx');
    expect(row?.value).toBe('4');
  });
});
