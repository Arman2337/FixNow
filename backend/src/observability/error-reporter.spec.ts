import {
  HttpErrorReporter,
  NoopErrorReporter,
  type ErrorReport,
} from './error-reporter';

/**
 * The properties that make the reporter safe to enable.
 *
 * The audit's requirement was only "error reporting reaches a human", but a
 * reporter that can hang a request, retry forever, or carry a request body to a
 * third party is worse than none of the three. These assert the report's shape
 * and the transport's failure behaviour rather than that a network call happened,
 * because the shape is the part that is this codebase's responsibility.
 */
describe('HttpErrorReporter', () => {
  const report: ErrorReport = {
    message: 'boom',
    name: 'TypeError',
    stack: 'TypeError: boom\n    at somewhere',
    correlationId: 'req-1',
    route: '/bookings',
    method: 'POST',
    status: 500,
    environment: 'test',
    release: 'v1.2.3',
    occurredAt: '2026-01-01T00:00:00.000Z',
  };

  const dsn = 'https://abc123@o0.ingest.sentry.io/42';

  let fetchMock: jest.Mock;
  beforeEach(() => {
    fetchMock = jest.fn().mockResolvedValue({ ok: true });
    global.fetch = fetchMock;
  });

  it('posts to the project envelope endpoint', async () => {
    await new HttpErrorReporter(dsn, 'test', 'v1.2.3').report(report);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [
      string,
      Record<string, unknown>,
    ];
    expect(url).toBe('https://sentry.io/api/42/envelope/');
    expect(init.method).toBe('POST');
    expect(init.keepalive).toBe(true);
  });

  it('sends a two-line NDJSON envelope, not a bare object', async () => {
    // The envelope format is specific, and a subtly wrong one is dropped by the
    // receiver â€” which looks exactly like "no errors are happening".
    await new HttpErrorReporter(dsn, 'test').report(report);

    const [, init] = fetchMock.mock.calls[0] as [
      string,
      Record<string, unknown>,
    ];
    const body = init.body as string;
    const lines = body.trim().split('\n');
    expect(lines).toHaveLength(2);

    const header = JSON.parse(lines[0]) as { dsn: string; event_id: string };
    expect(header.dsn).toBe(dsn);
    expect(header.event_id).toMatch(/^[0-9a-f]{32}$/);

    const event = JSON.parse(lines[1]) as ErrorReport;
    expect(event.message).toBe('boom');
    expect(event.correlationId).toBe('req-1');
    expect(event.route).toBe('/bookings');
  });

  it('carries no request body, headers or user object', async () => {
    await new HttpErrorReporter(dsn, 'test').report(report);
    const [, init] = fetchMock.mock.calls[0] as [
      string,
      Record<string, unknown>,
    ];

    expect(init.body as string).not.toMatch(
      /phone|email|authorization|password|body/i,
    );
  });

  it('swallows a transport failure rather than propagating it', async () => {
    // An observability tool must never be the outage it exists to explain.
    fetchMock.mockRejectedValue(new Error('network down'));
    await expect(
      new HttpErrorReporter(dsn, 'test').report(report),
    ).resolves.toBeUndefined();
  });

  it('swallows an HTTP error status', async () => {
    fetchMock.mockResolvedValue({ ok: false, status: 429 });
    await expect(
      new HttpErrorReporter(dsn, 'test').report(report),
    ).resolves.toBeUndefined();
  });

  it('bounds the attempt so a hung reporter cannot stall a request', async () => {
    await new HttpErrorReporter(dsn, 'test').report(report);
    const [, init] = fetchMock.mock.calls[0] as [
      string,
      Record<string, unknown>,
    ];
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it('sends nothing for a DSN that is not a URL', async () => {
    await new HttpErrorReporter('not-a-dsn', 'test').report(report);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('sends nothing for a DSN with no project id', async () => {
    await new HttpErrorReporter('https://key@sentry.io/', 'test').report(
      report,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('does not send credentials to the ingest host', async () => {
    // The DSN's userinfo is the public key, but sending it in a header or the
    // URL path would leak it to whatever host the DSN names.
    await new HttpErrorReporter(dsn, 'test').report(report);
    const [url, init] = fetchMock.mock.calls[0] as [
      string,
      Record<string, unknown>,
    ];
    expect(url).not.toContain('abc123');
    expect(JSON.stringify(init.headers)).not.toContain('abc123');
  });
});

describe('NoopErrorReporter', () => {
  it('drops everything, because an unconfigured deployment has no DSN', () => {
    const reporter = new NoopErrorReporter();
    expect(reporter.report()).toBeUndefined();
  });
});
