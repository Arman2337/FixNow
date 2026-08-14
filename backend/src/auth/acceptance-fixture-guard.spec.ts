/* eslint-disable prettier/prettier */
import { assertSafeAcceptanceFixtureEnvironment } from './acceptance-fixture-guard';

describe('acceptance fixture environment guard', () => {
  const development = {
    NODE_ENV: 'development',
    ACCEPTANCE_FIXTURES_ENABLED: 'true',
    DATABASE_URL: 'postgresql://user:password@127.0.0.1:5432/fixnow_dev',
  };

  it('allows an explicitly enabled loopback development database', () => {
    expect(() => assertSafeAcceptanceFixtureEnvironment(development)).not.toThrow();
  });

  it('allows the isolated test database', () => {
    expect(() =>
      assertSafeAcceptanceFixtureEnvironment({
        ...development,
        NODE_ENV: 'test',
        TEST_DATABASE_URL: 'postgresql://user:password@localhost:5432/fixnow_test',
      }),
    ).not.toThrow();
  });

  it.each([
    ['production', { ...development, NODE_ENV: 'production' }],
    ['missing opt-in flag', { ...development, ACCEPTANCE_FIXTURES_ENABLED: 'false' }],
    ['non-loopback host', {
      ...development,
      DATABASE_URL: 'postgresql://user:password@db.internal:5432/fixnow_dev',
    }],
    ['shared database name', {
      ...development,
      DATABASE_URL: 'postgresql://user:password@127.0.0.1:5432/shared',
    }],
  ])('rejects %s', (_description, env) => {
    expect(() => assertSafeAcceptanceFixtureEnvironment(env)).toThrow();
  });
});
