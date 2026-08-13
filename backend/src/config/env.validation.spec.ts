import { validate } from './env.validation';

describe('Environment Validation', () => {
  it('should validate valid configuration', () => {
    const validConfig = {
      NODE_ENV: 'development',
      PORT: '3000',
      LOG_LEVEL: 'info',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
    };
    const result = validate(validConfig);
    expect(result.NODE_ENV).toBe('development');
    expect(result.PORT).toBe(3000); // Converted to number
    expect(result.LOG_LEVEL).toBe('info');
  });

  it('should throw an error for invalid configuration', () => {
    const invalidConfig = {
      NODE_ENV: 'invalid-env', // Not a valid enum
    };
    expect(() => validate(invalidConfig)).toThrow();
  });

  it('should use default values for missing optional properties', () => {
    const emptyConfig = {
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
    };
    const result = validate(emptyConfig);
    expect(result.NODE_ENV).toBe('development');
    expect(result.PORT).toBe(3000);
    expect(result.LOG_LEVEL).toBe('info');
  });

  it('accepts loopback HTTP real-time origins only outside production', () => {
    const base = {
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
      REALTIME_ALLOWED_ORIGINS: 'http://localhost:3000',
    };
    expect(validate(base).REALTIME_ALLOWED_ORIGINS).toBe(
      'http://localhost:3000',
    );
    expect(() => validate({ ...base, NODE_ENV: 'production' })).toThrow(
      'REALTIME_ALLOWED_ORIGINS must use HTTPS origins',
    );
  });

  it('rejects real-time allowlist entries containing paths or credentials', () => {
    const base = {
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
    };
    expect(() =>
      validate({
        ...base,
        REALTIME_ALLOWED_ORIGINS: 'https://app.fixnow.test/path',
      }),
    ).toThrow('REALTIME_ALLOWED_ORIGINS must use HTTPS origins');
    expect(() =>
      validate({
        ...base,
        REALTIME_ALLOWED_ORIGINS: 'https://user:pass@app.fixnow.test',
      }),
    ).toThrow('REALTIME_ALLOWED_ORIGINS must use HTTPS origins');
  });

  it('validates browser HTTP origins with the same secure policy', () => {
    const base = {
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
      WEB_ALLOWED_ORIGINS: 'http://127.0.0.1:8080,https://app.fixnow.test',
    };
    expect(validate(base).WEB_ALLOWED_ORIGINS).toBe(base.WEB_ALLOWED_ORIGINS);
    expect(() => validate({ ...base, NODE_ENV: 'production' })).toThrow(
      'WEB_ALLOWED_ORIGINS must use HTTPS origins',
    );
  });

  it('validates bounded and internally consistent live-location policy', () => {
    const base = {
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
    };
    expect(
      validate({ ...base, LOCATION_UPDATE_INTERVAL_MS: '15000' })
        .LOCATION_UPDATE_INTERVAL_MS,
    ).toBe(15_000);
    expect(() =>
      validate({ ...base, LOCATION_UPDATE_INTERVAL_MS: '9999' }),
    ).toThrow();
    expect(() =>
      validate({
        ...base,
        LOCATION_STALE_AFTER_MS: '60000',
        LOCATION_CACHE_TTL_MS: '60001',
      }),
    ).toThrow('LOCATION_CACHE_TTL_MS must not exceed LOCATION_STALE_AFTER_MS');
  });
});
