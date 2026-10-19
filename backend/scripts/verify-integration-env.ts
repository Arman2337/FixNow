/**
 * Fails before jest is invoked when the integration suite cannot run.
 *
 * TEST-003. The suite is gated on an isolated PostgreSQL that nothing
 * provisioned. Every spec repeats the same guard at module scope - loopback,
 * port 55432, role `fixnow_test`, database `fixnow_test - and every one of them
 * throws "TEST_DATABASE_URL must target an isolated test database" when the
 * variable is absent. Nine specs, nine identical stack traces, none of which
 * says how to fix it. Worse, `test/jest-integration.json` did not reference
 * `test/setup.ts`, so nothing seeded the environment either, and CI ran
 * `jest` with the unit config, which excludes `*.integration.spec.ts` by
 * regex. The suite had never been executed by anyone.
 *
 * The safety guard stays exactly where it is, in the specs, right next to the
 * TRUNCATE that makes it matter. This script does not weaken or duplicate it;
 * it only turns "absent or wrong" into one sentence that says what to run.
 *
 * Usage: npm run test:integration   (npm runs pretest:integration first)
 */
import 'dotenv/config';

const EXPECTED = {
  protocol: 'postgresql:',
  hostnames: ['127.0.0.1', 'localhost'],
  port: '55432',
  username: 'fixnow_test',
  pathname: '/fixnow_test',
} as const;

const PROVISION = [
  'docker run -d --name fixnow-test-db \\',
  '  -p 55432:5432 \\',
  '  -e POSTGRES_USER=fixnow_test \\',
  '  -e POSTGRES_PASSWORD=fixnow_test \\',
  '  -e POSTGRES_DB=fixnow_test \\',
  '  postgres:16-alpine',
  '',
  'npm run migration:run',
  '',
  'export TEST_DATABASE_URL=postgresql://fixnow_test:fixnow_test@127.0.0.1:55432/fixnow_test',
];

function fail(problem: string, detail?: string): never {
  console.error(`Cannot run the integration suite: ${problem}`);
  if (detail) console.error(detail);
  console.error('');
  console.error(
    [
      'These tests TRUNCATE, so they only run against a dedicated throwaway',
      'database. To provision one:',
      '',
      ...PROVISION,
      '',
      'CI provisions the same database; see .github/workflows/ci.yml.',
    ].join('\n'),
  );
  process.exit(1);
}

function main(): void {
  const raw = process.env.TEST_DATABASE_URL;
  if (!raw) fail('TEST_DATABASE_URL is not set');

  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    fail('TEST_DATABASE_URL is not a valid URL', `  got: ${raw}`);
  }

  const hostnames = ['127.0.0.1', 'localhost'];
  const isDedicatedTestPort =
    url.port === '55432' &&
    url.username === 'fixnow_test' &&
    url.pathname === '/fixnow_test';
  const isDedicatedTestDbOnDefaultPort =
    (url.port === '5432' || url.port === '') &&
    (url.pathname === '/fixnow_integration_test' ||
      url.pathname === '/fixnow_test');

  const mismatches: string[] = [];
  if (url.protocol !== 'postgresql:')
    mismatches.push(`protocol must be postgresql:, got ${url.protocol}`);
  if (!hostnames.includes(url.hostname))
    mismatches.push(
      `host must be one of ${hostnames.join(', ')}, got ${url.hostname}`,
    );
  if (!isDedicatedTestPort && !isDedicatedTestDbOnDefaultPort)
    mismatches.push(
      `database must be port 55432 on /fixnow_test OR port 5432 on /fixnow_integration_test, got port ${url.port || '(none)'} with path ${url.pathname}`,
    );

  if (mismatches.length > 0) {
    fail(
      'TEST_DATABASE_URL does not name the isolated test database',
      mismatches.map((m) => `  - ${m}`).join('\n'),
    );
  }

  console.log(`Integration database: ${url.host}${url.pathname} (isolated)`);
}

main();
