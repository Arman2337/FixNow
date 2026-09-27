/**
 * Builds a brand-new database from every migration, then runs the schema gate
 * against it.
 *
 * This is the check that was missing: nothing in the build ever created a
 * database from scratch, so a migration that quietly dropped a table, a
 * constraint or a default could pass review and still leave production broken.
 *
 * Usage: npm run schema:verify:fresh
 */
import 'dotenv/config';
import { DataSource } from 'typeorm';
import { spawnSync } from 'child_process';
import { join } from 'path';
import { migrationDataSourceOptions } from '../src/database/data-source';

const SCRATCH = process.env.SCHEMA_SCRATCH_DB || 'fixnow_schema_gate';

const FIXTURE_USER = '00000000-0000-4000-8000-0000000000a1';
const FIXTURE_CATEGORY = '00000000-0000-4000-8000-0000000000b1';

// The scratch name is interpolated into DDL, so refuse anything that is not a
// plain identifier rather than trusting the environment.
if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(SCRATCH)) {
  console.error(
    `SCHEMA_SCRATCH_DB must be a plain identifier, got: ${SCRATCH}`,
  );
  process.exit(2);
}

function withUrl(url: string): DataSource {
  return new DataSource({
    ...(migrationDataSourceOptions as unknown as Record<string, unknown>),
    url,
  } as never);
}

async function recreateScratchDatabase(): Promise<string> {
  const admin = withUrl(process.env.DATABASE_URL as string);
  await admin.initialize();

  // A leftover database from a previous failed run would make this lie.
  await admin.query(
    `SELECT pg_terminate_backend(pid) FROM pg_stat_activity
      WHERE datname = '${SCRATCH}' AND pid <> pg_backend_pid()`,
  );
  await admin.query(`DROP DATABASE IF EXISTS "${SCRATCH}"`);
  await admin.query(`CREATE DATABASE "${SCRATCH}"`);
  await admin.destroy();

  const url = new URL(process.env.DATABASE_URL as string);
  url.pathname = `/${SCRATCH}`;
  return url.toString();
}

async function main(): Promise<void> {
  const scratchUrl = await recreateScratchDatabase();
  console.log(`built empty database: ${SCRATCH}`);

  const ds = withUrl(scratchUrl);
  await ds.initialize();

  // uuid-ossp/uuid_generate_v4 is required by the earliest migrations.
  const boot = ds.createQueryRunner();
  await boot.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
  await boot.query('CREATE EXTENSION IF NOT EXISTS pgcrypto');
  await boot.release();

  console.log('\napplying migrations in order...');
  let broke: string | undefined;
  try {
    const applied = await ds.runMigrations({ transaction: 'each' });
    console.log(`  applied ${applied.length} migrations`);
  } catch (e) {
    const err = e as {
      name?: string;
      driverError?: { message?: string; code?: string };
    };
    broke = err.name ?? 'unknown';
    console.error('\nMIGRATION CHAIN FAILED');
    console.error(`  migration : ${broke}`);
    console.error(`  sqlstate  : ${err.driverError?.code ?? '?'}`);
    console.error(
      `  message   : ${err.driverError?.message ?? (e as Error).message}`,
    );
  }

  if (!broke) {
    // Seed the two rows the write-path assertions need. Without them the gate
    // would quietly skip the checks that actually prove the constraints bite,
    // which are the checks worth having. A QueryRunner is used because
    // DataSource.query does not accept bind parameters.
    console.log('\nseeding fixtures for the write checks...');
    const seeder = ds.createQueryRunner();
    await seeder.query(
      `INSERT INTO users (id, phone, status, created_at, updated_at)
       VALUES ($1, '+919000000001', 'active', now(), now())
       ON CONFLICT DO NOTHING`,
      [FIXTURE_USER],
    );
    await seeder.query(
      `INSERT INTO service_categories
         (id, name, slug, description, icon_name, display_order, is_active,
          is_emergency, created_at, updated_at)
       VALUES ($1, 'Schema Gate Category', 'schema-gate-category', 'fixture',
               'build', 0, true, false, now(), now())
       ON CONFLICT DO NOTHING`,
      [FIXTURE_CATEGORY],
    );
    await seeder.release();
  }

  await ds.destroy();
  if (broke) {
    process.exit(1);
  }

  console.log('\nrunning schema gate against the freshly built database...\n');
  const result = spawnSync(
    process.execPath,
    [
      '-r',
      'ts-node/register',
      '-r',
      'tsconfig-paths/register',
      join(__dirname, 'verify-schema.ts'),
    ],
    {
      stdio: 'inherit',
      env: { ...process.env, DATABASE_URL: scratchUrl },
      cwd: join(__dirname, '..'),
    },
  );
  process.exit(result.status ?? 1);
}

void main().catch((e: Error) => {
  console.error('fresh-schema check could not run:', e.message);
  process.exit(2);
});
