import 'reflect-metadata';
import { MetricRegistry } from './metric-registry';
import { ObservabilityService, METRICS } from './observability.service';

describe('MetricRegistry', () => {
  it('renders the Prometheus text format with HELP and TYPE', () => {
    const registry = new MetricRegistry();
    registry.counter('fixnow_test_total', 'A test counter.', ['reason']);
    registry.inc('fixnow_test_total', { reason: 'ok' });

    const output = registry.render();
    expect(output).toContain('# HELP fixnow_test_total A test counter.');
    expect(output).toContain('# TYPE fixnow_test_total counter');
    expect(output).toContain('fixnow_test_total{reason="ok"} 1');
  });

  it('accumulates a counter across increments', () => {
    const registry = new MetricRegistry();
    registry.counter('fixnow_test_total', 'A test counter.', ['reason']);
    registry.inc('fixnow_test_total', { reason: 'ok' });
    registry.inc('fixnow_test_total', { reason: 'ok' });
    registry.inc('fixnow_test_total', { reason: 'ok' }, 5);

    expect(registry.render()).toContain('fixnow_test_total{reason="ok"} 7');
  });

  it('keeps separate series per label set', () => {
    const registry = new MetricRegistry();
    registry.counter('fixnow_test_total', 'A test counter.', ['reason']);
    registry.inc('fixnow_test_total', { reason: 'ok' });
    registry.inc('fixnow_test_total', { reason: 'failed' });

    const output = registry.render();
    expect(output).toContain('fixnow_test_total{reason="ok"} 1');
    expect(output).toContain('fixnow_test_total{reason="failed"} 1');
  });

  it('resolves the same series regardless of label argument order', () => {
    // Without canonicalising, `{route, method}` and `{method, route}` would
    // create two series that look identical in a query and are not.
    const registry = new MetricRegistry();
    registry.counter('fixnow_test_total', 'A test counter.', [
      'route',
      'method',
    ]);
    registry.inc('fixnow_test_total', { route: '/a', method: 'GET' });
    registry.inc('fixnow_test_total', { method: 'GET', route: '/a' });

    const lines = registry
      .render()
      .split('\n')
      .filter((line) => line.startsWith('fixnow_test_total{'));
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain(' 2');
  });

  it('rejects a set on an undeclared metric', () => {
    const registry = new MetricRegistry();
    // A typo must be an exception, not a silently-ignored write. A metric that
    // quietly stops being recorded is worse than one that never existed,
    // because the dashboard still shows it.
    expect(() => registry.set('fixnow_never_declared', 1)).toThrow(
      /No gauge named/,
    );
  });

  it('rejects redeclaring a metric with a different shape', () => {
    const registry = new MetricRegistry();
    registry.gauge('fixnow_test', 'One help text.');
    expect(() =>
      registry.gauge('fixnow_test', 'A different help text.'),
    ).toThrow(/already declared/);
    expect(() =>
      registry.gauge('fixnow_test', 'One help text.', ['a']),
    ).toThrow(/already declared/);
  });

  it('allows redeclaring an identical metric, which is how modules compose', () => {
    const registry = new MetricRegistry();
    registry.gauge('fixnow_test', 'One help text.');
    expect(() => registry.gauge('fixnow_test', 'One help text.')).not.toThrow();
  });

  describe('histograms', () => {
    it('writes cumulative buckets', () => {
      const registry = new MetricRegistry();
      const histogram = registry.histogram(
        'fixnow_test_seconds',
        'A test histogram.',
        [0.1, 0.5, 1],
      );

      histogram.observe(0.05);
      histogram.observe(0.3);
      histogram.observe(2);

      const output = registry.render();
      // Every observation counts toward every bound at or above it, which is
      // what makes `le` meaningful to a query.
      expect(output).toContain('fixnow_test_seconds_bucket{le="0.1"} 1');
      expect(output).toContain('fixnow_test_seconds_bucket{le="0.5"} 2');
      expect(output).toContain('fixnow_test_seconds_bucket{le="1"} 2');
      expect(output).toContain('fixnow_test_seconds_bucket{le="+Inf"} 3');
    });

    it('keeps _count and _sum consistent with the +Inf bucket', () => {
      const registry = new MetricRegistry();
      const histogram = registry.histogram(
        'fixnow_test_seconds',
        'A test.',
        [1],
      );
      histogram.observe(0.4);
      histogram.observe(0.6);

      const output = registry.render();
      const inf = /le="\+Inf"\} (\d+)/.exec(output)?.[1];
      const count = /_count(?:\{\})? (\d+)/.exec(output)?.[1];
      expect(inf).toBe(count);
    });

    it('renders labelled buckets with the label set intact', () => {
      const registry = new MetricRegistry();
      const histogram = registry.histogram(
        'fixnow_test_seconds',
        'A test.',
        [1],
        ['route'],
      );
      histogram.observe(0.5, { route: '/bookings' });

      expect(registry.render()).toContain(
        'fixnow_test_seconds_bucket{route="/bookings",le="1"} 1',
      );
    });

    it('sorts bounds so `le` is monotonic whatever order they were given', () => {
      const registry = new MetricRegistry();
      const histogram = registry.histogram(
        'fixnow_test_seconds',
        'A test.',
        [10, 0.1, 1],
      );
      histogram.observe(0.5);

      const output = registry.render();
      const buckets = [...output.matchAll(/le="([^"]+)"/g)].map((m) => m[1]);
      expect(buckets).toEqual(['0.1', '1', '10', '+Inf']);
    });
  });
});

describe('ObservabilityService', () => {
  let observability: ObservabilityService;

  beforeEach(() => {
    observability = new ObservabilityService();
  });

  it('exposes the no-provider rate the audit said was uncomputable', () => {
    observability.observeBookingCreate(0.2, 'created');
    observability.observeBookingCreate(0.3, 'created');
    observability.observeBookingCreate(0.4, 'no_provider');

    const output = observability.render();
    expect(output).toContain(
      'fixnow_bookings_created_total{providers_available="true"} 2',
    );
    expect(output).toContain(
      'fixnow_bookings_created_total{providers_available="false"} 1',
    );
  });

  it('records matching duration on the eligibility stage', () => {
    observability.observeMatching(0.01, 'eligibility');
    const output = observability.render();
    expect(output).toContain(
      '# TYPE fixnow_matching_duration_seconds histogram',
    );
    expect(output).toContain(
      'fixnow_matching_duration_seconds_count{stage="eligibility"} 1',
    );
  });

  it('records the outbox backlog as a gauge', () => {
    observability.setOutboxBacklog(412);
    expect(observability.render()).toContain('fixnow_outbox_backlog 412');
  });

  it('records dependency health as 1 or 0', () => {
    observability.setDependencyUp('redis', true);
    observability.setDependencyUp('database', false);
    const output = observability.render();
    expect(output).toContain('fixnow_dependency_up{dependency="redis"} 1');
    expect(output).toContain('fixnow_dependency_up{dependency="database"} 0');
  });

  it('records dispatch offers by wave and outcome', () => {
    observability.countDispatchOffer(1, 'sent');
    observability.countDispatchOffer(1, 'accepted');
    observability.countDispatchOffer(2, 'sent');
    const output = observability.render();
    expect(output).toContain(
      'fixnow_dispatch_offers_total{wave="1",outcome="sent"} 1',
    );
    expect(output).toContain(
      'fixnow_dispatch_offers_total{wave="1",outcome="accepted"} 1',
    );
    expect(output).toContain(
      'fixnow_dispatch_offers_total{wave="2",outcome="sent"} 1',
    );
  });

  it('exposes no customer, booking or payment identifier', () => {
    // The endpoint is unauthenticated, so the guarantee that matters is what it
    // cannot leak. A label carrying a uuid would be a data breach with a scrape
    // config attached to it.
    observability.observeBookingCreate(0.1, 'created');
    observability.setOutboxBacklog(3);
    observability.setDependencyUp('redis', true);
    observability.setRealtimeConnections(12);
    observability.countDispatchOffer(1, 'sent');
    observability.observeFanout(0.4, 'push');
    observability.observeMatching(0.01, 'eligibility');

    const output = observability.render();
    expect(output).not.toMatch(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}/i);
    expect(output).not.toMatch(/customerId|bookingId|orderId|phone|email/i);
  });

  it('declares every metric name it advertises', () => {
    // A name in METRICS that nothing registers would be a dashboard tile that
    // silently never populates — the exact failure the audit found in the
    // existing dashboards.
    const output = observability.render();
    for (const name of Object.values(METRICS)) {
      expect(output).toContain(name);
    }
  });
});
