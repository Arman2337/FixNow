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
    };
    const result = validate(emptyConfig);
    expect(result.NODE_ENV).toBe('development');
    expect(result.PORT).toBe(3000);
    expect(result.LOG_LEVEL).toBe('info');
  });
});
