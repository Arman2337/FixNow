import { randomUUID } from 'node:crypto';
import { RequestCorrelationMiddleware } from './request-correlation.middleware';
import { CORRELATION_HEADER, resolveRequestId } from './request-correlation';

describe('resolveRequestId', () => {
  it('keeps a safe inbound id so traces continue across a deployment', () => {
    expect(resolveRequestId('4bf92f3577b34da6a3ce929d0e0e4736')).toBe(
      '4bf92f3577b34da6a3ce929d0e0e4736',
    );
  });

  // The inbound header is attacker-controlled on any request that did not come
  // through our own proxy, and it is written into log output.
  it('replaces an id carrying a newline, which would forge a log line', () => {
    const forged = 'aaaaaaaa\n{"level":"error","msg":"forged"}';
    const resolved = resolveRequestId(forged);

    expect(resolved).not.toBe(forged);
    expect(resolved).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('replaces an id carrying a carriage return', () => {
    expect(resolveRequestId('aaaaaaaa\rfoo')).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('replaces an id that is too long to be worth logging', () => {
    expect(resolveRequestId('a'.repeat(500))).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('replaces a too-short id', () => {
    expect(resolveRequestId('short')).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('rejects non-string and missing headers', () => {
    expect(resolveRequestId(undefined)).toMatch(/^[0-9a-f-]{36}$/);
    expect(resolveRequestId(42)).toMatch(/^[0-9a-f-]{36}$/);
    expect(resolveRequestId(['a'.repeat(40)])).toBe('a'.repeat(40));
  });

  it('generates distinct ids', () => {
    expect(resolveRequestId(undefined)).not.toBe(randomUUID());
  });
});

describe('RequestCorrelationMiddleware', () => {
  it('echoes the id that appears on the request log lines', () => {
    const headers: Record<string, string> = {};
    const next = jest.fn();

    new RequestCorrelationMiddleware().use(
      { id: 'req-abc-123' } as never,
      { setHeader: (k: string, v: string) => (headers[k] = v) } as never,
      next,
    );

    expect(headers[CORRELATION_HEADER]).toBe('req-abc-123');
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('sets no header when the request has no id', () => {
    const headers: Record<string, string> = {};
    const next = jest.fn();

    new RequestCorrelationMiddleware().use(
      {} as never,
      { setHeader: (k: string, v: string) => (headers[k] = v) } as never,
      next,
    );

    expect(headers[CORRELATION_HEADER]).toBeUndefined();
    expect(next).toHaveBeenCalledTimes(1);
  });
});
