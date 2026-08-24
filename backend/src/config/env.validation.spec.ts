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
    expect(result.LOCAL_OTP_BYPASS_ENABLED).toBe('false');
  });

  it('allows the local OTP bypass only in development', () => {
    const base = {
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
      LOCAL_OTP_BYPASS_ENABLED: 'true',
    };

    expect(validate(base).LOCAL_OTP_BYPASS_ENABLED).toBe('true');
    expect(() => validate({ ...base, NODE_ENV: 'test' })).toThrow(
      'LOCAL_OTP_BYPASS_ENABLED may be enabled only in development',
    );
    expect(() => validate({ ...base, NODE_ENV: 'production' })).toThrow(
      'LOCAL_OTP_BYPASS_ENABLED may be enabled only in development',
    );
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

  it('fails closed for unsupported or unsafe AI provider configuration', () => {
    const base = {
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
    };

    expect(() => validate({ ...base, AI_ENABLED: 'true' })).toThrow(
      'AI_ENABLED requires a supported AI_PROVIDER',
    );
    expect(() => validate({ ...base, AI_PROVIDER: 'unknown' })).toThrow();
    expect(() =>
      validate({ ...base, NODE_ENV: 'production', AI_PROVIDER: 'fake' }),
    ).toThrow('AI_PROVIDER=fake is prohibited in production');
  });
});

describe('Push notification configuration', () => {
  const base = {
    DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
    REDIS_URL: 'redis://localhost:6379',
    JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
    OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
  };

  it('defaults to the disabled push provider', () => {
    expect(validate(base).PUSH_PROVIDER).toBe('disabled');
  });

  it('rejects an invalid push provider value', () => {
    expect(() => validate({ ...base, PUSH_PROVIDER: 'apns' })).toThrow();
  });

  it('prohibits the fake provider in production', () => {
    expect(() =>
      validate({ ...base, NODE_ENV: 'production', PUSH_PROVIDER: 'fake' }),
    ).toThrow(/fake is prohibited/);
  });

  it('requires a credential file for the fcm provider', () => {
    expect(() =>
      validate({
        ...base,
        NODE_ENV: 'development',
        PUSH_PROVIDER: 'fcm',
      }),
    ).toThrow(/FCM_CREDENTIALS_FILE/);
    const configured = validate({
      ...base,
      PUSH_PROVIDER: 'fcm',
      FCM_CREDENTIALS_FILE: '/untracked/local/service-account.json',
    });
    expect(configured.PUSH_PROVIDER).toBe('fcm');
  });
});

describe('Payment configuration', () => {
  const base = {
    DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/test',
    REDIS_URL: 'redis://localhost:6379',
    JWT_SECRET: 'test-only-jwt-secret-at-least-32-characters',
    OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
  };

  it('defaults to the fake provider outside production', () => {
    expect(validate(base).PAYMENT_PROVIDER).toBe('fake');
  });

  it('prohibits the fake provider in production', () => {
    expect(() =>
      validate({ ...base, NODE_ENV: 'production', PAYMENT_PROVIDER: 'fake' }),
    ).toThrow('PAYMENT_PROVIDER=fake is prohibited in production');
  });

  it('rejects unsupported provider values', () => {
    expect(() => validate({ ...base, PAYMENT_PROVIDER: 'stripe' })).toThrow(
      /PAYMENT_PROVIDER/,
    );
  });

  it('requires all three Razorpay credentials for the razorpay provider', () => {
    const withKeys = {
      ...base,
      PAYMENT_PROVIDER: 'razorpay',
      RAZORPAY_KEY_ID: 'rzp_test_x',
      RAZORPAY_KEY_SECRET: 'secret',
      RAZORPAY_WEBHOOK_SECRET: 'webhook-secret',
    };
    expect(validate(withKeys).PAYMENT_PROVIDER).toBe('razorpay');

    const partial: Record<string, string | undefined> = { ...withKeys };
    partial.RAZORPAY_WEBHOOK_SECRET = undefined;
    expect(() => validate(partial)).toThrow(/RAZORPAY_WEBHOOK_SECRET/);
  });
});
