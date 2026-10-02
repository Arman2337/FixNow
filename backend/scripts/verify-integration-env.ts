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

  const mismatches: string[] = [];
  if (url.protocol !== EXPECTED.protocol)
    mismatches.push(
      `protocol must be ${EXPECTED.protocol}, got ${url.protocol}`,
    );
  if (!(EXPECTED.hostnames as readonly string[]).includes(url.hostname))
    mismatches.push(
      `host must be one of ${EXPECTED.hostnames.join(', ')}, got ${url.hostname}`,
    );
  if (url.port !== EXPECTED.port)
    mismatches.push(
      `port must be ${EXPECTED.port}, got ${url.port || '(none)'}`,
    );
  if (url.username !== EXPECTED.username)
    mismatches.push(
      `user must be ${EXPECTED.username}, got ${url.username || '(none)'}`,
    );
  if (url.pathname !== EXPECTED.pathname)
    mismatches.push(
      `database must be ${EXPECTED.pathname}, got ${url.pathname}`,
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
