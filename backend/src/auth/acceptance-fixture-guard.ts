export const ACCEPTANCE_FIXTURE_FLAG = 'ACCEPTANCE_FIXTURES_ENABLED';

export function assertSafeAcceptanceFixtureEnvironment(
  env: NodeJS.ProcessEnv,
): void {
  if (!['development', 'test'].includes(env.NODE_ENV ?? '')) {
    throw new Error('Acceptance fixtures require NODE_ENV=development or test');
  }
  if (env[ACCEPTANCE_FIXTURE_FLAG] !== 'true') {
    throw new Error(
      `${ACCEPTANCE_FIXTURE_FLAG}=true is required to install acceptance fixtures`,
    );
  }

  const databaseUrl = env.TEST_DATABASE_URL ?? env.DATABASE_URL;
  if (!databaseUrl) throw new Error('An isolated DATABASE_URL is required');

  let parsed: URL;
  try {
    parsed = new URL(databaseUrl);
  } catch {
    throw new Error('DATABASE_URL must be a valid URL');
  }

  if (
    !['localhost', '127.0.0.1', '::1'].includes(parsed.hostname) ||
    !/^\/(fixnow_(dev|test)|postgres)$/.test(parsed.pathname)
  ) {
    throw new Error(
      'Acceptance fixtures require a loopback fixnow_dev or fixnow_test database',
    );
  }
}
