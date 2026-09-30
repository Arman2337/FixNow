/**
 * Environment seeding for the integration suite.
 *
 * TEST-003: this file existed but neither jest config referenced it, so
 * `npm run test:integration` started with an empty environment. Every spec
 * reads `TEST_DATABASE_URL` at module scope and throws when it is absent, so
 * the suite could only ever fail - and it was never run, locally or in CI.
 * `test/jest-integration.json` now loads it via `setupFiles`, which runs before
 * any spec module is evaluated.
 *
 * `TEST_DATABASE_URL` is deliberately NOT defaulted to anything that looks
 * plausible. These tests TRUNCATE, and every spec carries a guard that refuses
 * to run unless the target is loopback, port 55432, role `fixnow_test`,
 * database `fixnow_test`. Inventing a default here would be the single most
 * dangerous thing this file could do. `pretest:integration` runs
 * `scripts/verify-integration-env.ts`, which turns an absent or wrong URL into
 * one actionable message before jest is even invoked.
 */
process.env.DATABASE_URL =
  process.env.TEST_DATABASE_URL ??
  'postgresql://fixnow:replace-me@localhost:5432/fixnow';
process.env.REDIS_URL = process.env.TEST_REDIS_URL ?? 'redis://localhost:6379';
process.env.NODE_ENV = 'test';
process.env.LOCAL_OTP_BYPASS_ENABLED = 'false';
process.env.JWT_SECRET = 'test-only-jwt-secret-at-least-32-characters';
process.env.OTP_SECRET = 'test-only-otp-secret-at-least-32-characters';
