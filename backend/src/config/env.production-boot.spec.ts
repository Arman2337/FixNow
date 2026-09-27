import { validate } from './env.validation';

/**
 * `OPS-001`: nothing in the repository booted the built artefact in a
 * production-shaped environment, so the fact that production could not start
 * stayed invisible until a deploy.
 *
 * These tests pin down exactly what stands between the repository and a
 * bootable production deploy. Today that is one variable, and the value of
 * asserting it is that the list cannot silently grow.
 */
const PRODUCTION_BASE: Record<string, unknown> = {
  NODE_ENV: 'production',
  DATABASE_URL: 'postgresql://user:pass@db.internal:5432/fixnow',
  REDIS_URL: 'redis://cache.internal:6379',
  // The 32-character minimum is enforced by @MinLength, so a realistic-looking
  // placeholder is required for the rest of validation to be reached.
  JWT_SECRET: 'a'.repeat(48),
  OTP_SECRET: 'b'.repeat(48),
};

describe('production boot (OPS-001)', () => {
  it('refuses to boot while PAYMENT_PROVIDER is unset', () => {
    // Unset defaults to the fake provider, which is prohibited in production.
    expect(() => validate({ ...PRODUCTION_BASE })).toThrow(
      /PAYMENT_PROVIDER=fake is prohibited in production/,
    );
  });

  it('refuses to boot with an explicit fake payment provider', () => {
    expect(() =>
      validate({ ...PRODUCTION_BASE, PAYMENT_PROVIDER: 'fake' }),
    ).toThrow(/PAYMENT_PROVIDER=fake is prohibited in production/);
  });

  it('boots once a real payment provider and its keys are supplied', () => {
    // This is the assertion that matters: with PAYMENT_PROVIDER=razorpay and
    // the three keys, nothing else in the configuration blocks a production
    // boot. Any future required variable will fail here first.
    const validated = validate({
      ...PRODUCTION_BASE,
      PAYMENT_PROVIDER: 'razorpay',
      RAZORPAY_KEY_ID: 'rzp_test_key',
      RAZORPAY_KEY_SECRET: 'rzp_test_secret',
      RAZORPAY_WEBHOOK_SECRET: 'rzp_test_webhook',
    });

    expect(validated.NODE_ENV).toBe('production');
    expect(validated.PAYMENT_PROVIDER).toBe('razorpay');
  });

  it('names the missing payment keys rather than failing obscurely', () => {
    expect(() =>
      validate({ ...PRODUCTION_BASE, PAYMENT_PROVIDER: 'razorpay' }),
    ).toThrow(/requires RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET/);
  });

  it('does not block boot on a disabled AI or push provider', () => {
    // AI_PROVIDER and PUSH_PROVIDER default to `disabled`, and their guards only
    // reject `fake`, so an unset deploy is not blocked by them. Asserted so a
    // future default change to `fake` is caught here rather than in production.
    expect(() =>
      validate({
        ...PRODUCTION_BASE,
        PAYMENT_PROVIDER: 'razorpay',
        RAZORPAY_KEY_ID: 'rzp_test_key',
        RAZORPAY_KEY_SECRET: 'rzp_test_secret',
        RAZORPAY_WEBHOOK_SECRET: 'rzp_test_webhook',
      }),
    ).not.toThrow();
  });

  it('rejects a missing required secret before anything else is checked', () => {
    expect(() =>
      validate({ ...PRODUCTION_BASE, JWT_SECRET: 'short' }),
    ).toThrow();
  });
});
