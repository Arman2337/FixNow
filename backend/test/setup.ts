process.env.DATABASE_URL =
  process.env.TEST_DATABASE_URL ??
  'postgresql://fixnow:replace-me@localhost:5432/fixnow';
process.env.REDIS_URL = 'redis://localhost:6379';
process.env.JWT_SECRET = 'test-only-jwt-secret-at-least-32-characters';
process.env.OTP_SECRET = 'test-only-otp-secret-at-least-32-characters';
