import { SecurityHeadersMiddleware } from './security-headers.middleware';
import { Environment } from '../../config/env.validation';

const makeRes = () => {
  const headers: Record<string, string> = {};
  const removed: string[] = [];
  return {
    headers,
    removed,
    setHeader: (name: string, value: string) => {
      headers[name] = value;
    },
    removeHeader: (name: string) => {
      removed.push(name);
    },
  };
};

const makeConfig = (overrides: Record<string, unknown> = {}) =>
  ({
    get: (key: string) => overrides[key],
  }) as never;

const run = (overrides: Record<string, unknown> = {}) => {
  const res = makeRes();
  const next = jest.fn();
  new SecurityHeadersMiddleware(makeConfig(overrides)).use(
    {} as never,
    res as never,
    next,
  );
  return { res, next };
};

describe('SecurityHeadersMiddleware', () => {
  it('sets the baseline headers and continues', () => {
    const { res, next } = run();

    expect(next).toHaveBeenCalledTimes(1);
    expect(res.headers['X-Content-Type-Options']).toBe('nosniff');
    expect(res.headers['X-Frame-Options']).toBe('DENY');
    expect(res.headers['Referrer-Policy']).toBe('no-referrer');
    expect(res.headers['Permissions-Policy']).toContain('camera=()');
    expect(res.removed).toContain('X-Powered-By');
  });

  it('defaults the CSP to deny everything this API needs', () => {
    const { res } = run();

    expect(res.headers['Content-Security-Policy']).toBe(
      "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
    );
  });

  it('accepts a configured CSP', () => {
    const { res } = run({ CSP_DIRECTIVES: "default-src 'self'" });

    expect(res.headers['Content-Security-Policy']).toBe("default-src 'self'");
  });

  it('falls back to the default when the configured CSP is blank', () => {
    const { res } = run({ CSP_DIRECTIVES: '   ' });

    expect(res.headers['Content-Security-Policy']).toContain(
      "default-src 'none'",
    );
  });

  it('does not send HSTS outside production', () => {
    const { res } = run({
      NODE_ENV: Environment.Development,
      HSTS_MAX_AGE_SECONDS: 31536000,
    });

    // Sending this over plain HTTP would lock the browser out of the origin.
    expect(res.headers['Strict-Transport-Security']).toBeUndefined();
  });

  it('sends HSTS in production', () => {
    const { res } = run({
      NODE_ENV: Environment.Production,
      HSTS_MAX_AGE_SECONDS: 31536000,
    });

    expect(res.headers['Strict-Transport-Security']).toBe(
      'max-age=31536000; includeSubDomains',
    );
  });

  it('omits HSTS in production when no max-age is configured', () => {
    const { res } = run({ NODE_ENV: Environment.Production });

    expect(res.headers['Strict-Transport-Security']).toBeUndefined();
  });
});
