/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access, prettier/prettier */
import { config as loadEnv } from 'dotenv';
import * as argon2 from 'argon2';
// @ts-expect-error pg is a runtime dependency without bundled declarations in this foundation
import { Pool, PoolClient } from 'pg';
import { join } from 'node:path';
import {
  assertSafeAcceptanceFixtureEnvironment,
} from '../src/auth/acceptance-fixture-guard';

loadEnv({ path: join(__dirname, '../.env') });

export const ACCEPTANCE_IDENTITIES = {
  customerA: {
    id: '10000000-0000-4000-8000-000000000001',
    email: 'fixnow.acceptance.customer-a@local.test',
    password: 'FixNow-local-customer-a-2026!',
  },
  providerA: {
    id: '10000000-0000-4000-8000-000000000002',
    email: 'fixnow.acceptance.provider-a@local.test',
    password: 'FixNow-local-provider-a-2026!',
  },
  providerB: {
    id: '10000000-0000-4000-8000-000000000003',
    email: 'fixnow.acceptance.provider-b@local.test',
    password: 'FixNow-local-provider-b-2026!',
  },
  reviewer: {
    id: '10000000-0000-4000-8000-000000000004',
    email: 'fixnow.acceptance.reviewer@local.test',
    password: 'FixNow-local-reviewer-2026!',
  },
  operationsAdmin: {
    id: '10000000-0000-4000-8000-000000000005',
    email: 'fixnow.acceptance.admin@local.test',
    password: 'FixNow-local-admin-2026!',
  },
} as const;

export const assertSafeFixtureEnvironment = assertSafeAcceptanceFixtureEnvironment;

async function main(command: 'seed' | 'cleanup'): Promise<void> {
  assertSafeAcceptanceFixtureEnvironment(process.env);
  const databaseUrl = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL!;
  const pool = new Pool({ connectionString: databaseUrl });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await cleanupUsers(client);
    if (command === 'seed') await seed(client);
    await client.query('COMMIT');
    console.log(
      command === 'seed'
        ? 'Acceptance fixtures installed for local testing.'
        : 'Acceptance fixture identities removed.',
    );
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

async function cleanupUsers(client: PoolClient): Promise<void> {
  await client.query('DELETE FROM "users" WHERE "id" = ANY($1::uuid[])', [
    Object.values(ACCEPTANCE_IDENTITIES).map(({ id }) => id),
  ]);
}

async function seed(client: PoolClient): Promise<void> {
  await ensureRole(client, 'customer', 'Customer account');
  await ensureRole(client, 'provider_applicant', 'Unverified provider applicant');
  await ensureRole(client, 'verified_provider', 'Approved provider');
  await ensureRole(client, 'provider_reviewer', 'Provider verification reviewer');
  await ensureRole(client, 'operations_administrator', 'Operations administrator');
  const category = await client.query<{ id: string }>(
    'SELECT "id" FROM "service_categories" WHERE "slug" = $1',
    ['plumbing'],
  );
  if (!category.rows[0]) throw new Error('The plumbing service category is missing; run migrations first');
  const categoryId = category.rows[0].id;

  await createIdentity(client, ACCEPTANCE_IDENTITIES.reviewer, 'provider_reviewer');
  await createIdentity(
    client,
    ACCEPTANCE_IDENTITIES.operationsAdmin,
    'operations_administrator',
  );
  await createIdentity(client, ACCEPTANCE_IDENTITIES.customerA, 'customer');
  await createIdentity(client, ACCEPTANCE_IDENTITIES.providerA, 'verified_provider');
  await createIdentity(client, ACCEPTANCE_IDENTITIES.providerB, 'verified_provider');

  for (const provider of [ACCEPTANCE_IDENTITIES.providerA, ACCEPTANCE_IDENTITIES.providerB]) {
    await client.query(
      `INSERT INTO "provider_applications"
        ("user_id", "status", "assigned_reviewer_user_id", "decision_reason", "reviewed_at", "version")
       VALUES ($1, 'approved', $2, 'Local acceptance fixture', NOW(), 1)
       ON CONFLICT ("user_id") DO UPDATE SET "status" = 'approved', "assigned_reviewer_user_id" = $2,
         "decision_reason" = 'Local acceptance fixture', "reviewed_at" = NOW(), "version" = 1`,
      [provider.id, ACCEPTANCE_IDENTITIES.reviewer.id],
    );
  }
  await client.query(
    `INSERT INTO "provider_profiles"
      ("user_id", "display_name", "bio", "service_radius_km", "base_latitude", "base_longitude")
     VALUES ($1, 'Acceptance Provider A', 'Synthetic local fixture', 25, 22.8982000, 72.9928000),
            ($2, 'Acceptance Provider B', 'Synthetic local fixture', 5, 22.7000010, 72.8700030)
     ON CONFLICT ("user_id") DO UPDATE SET "display_name" = EXCLUDED."display_name",
       "service_radius_km" = EXCLUDED."service_radius_km", "base_latitude" = EXCLUDED."base_latitude",
       "base_longitude" = EXCLUDED."base_longitude"`,
    [ACCEPTANCE_IDENTITIES.providerA.id, ACCEPTANCE_IDENTITIES.providerB.id],
  );
  for (const provider of [ACCEPTANCE_IDENTITIES.providerA, ACCEPTANCE_IDENTITIES.providerB]) {
    await client.query(
      `INSERT INTO "provider_skills"
        ("user_id", "service_category_id", "years_experience", "is_verified", "verification_notes")
       VALUES ($1, $2, 5, true, 'Local acceptance fixture')
       ON CONFLICT ("user_id", "service_category_id") DO UPDATE SET "is_verified" = true`,
      [provider.id, categoryId],
    );
    await client.query(
      `INSERT INTO "provider_availability"
        ("user_id", "time_zone", "weekly_rules", "exceptions", "status", "status_expires_at", "version")
       VALUES ($1, 'Asia/Kolkata', '[]'::jsonb, '[]'::jsonb, 'online', NOW() + INTERVAL '2 hours', 1)
       ON CONFLICT ("user_id") DO UPDATE SET "status" = 'online', "status_expires_at" = NOW() + INTERVAL '2 hours'`,
      [provider.id],
    );
  }
}

async function ensureRole(client: PoolClient, code: string, description: string): Promise<void> {
  await client.query(
    'INSERT INTO "roles" ("code", "description") VALUES ($1, $2) ON CONFLICT ("code") DO NOTHING',
    [code, description],
  );
}

async function createIdentity(
  client: PoolClient,
  identity: { id: string; email: string; password: string },
  role: string,
): Promise<void> {
  const hash = await argon2.hash(identity.password, { type: argon2.argon2id });
  const inserted = await client.query<{ id: string }>(
    `INSERT INTO "users" ("id", "status", "status_reason")
     VALUES ($1, 'active', 'Local acceptance fixture') RETURNING "id"`,
    [identity.id],
  );
  const userId = inserted.rows[0].id;
  const identityRow = await client.query<{ id: string }>(
    `INSERT INTO "user_identities" ("user_id", "provider", "subject", "verified_at")
     VALUES ($1, 'local_email', $2, NOW()) RETURNING "id"`,
    [userId, identity.email],
  );
  await client.query(
    'INSERT INTO "auth_credentials" ("identity_id", "password_hash") VALUES ($1, $2)',
    [identityRow.rows[0].id, hash],
  );
  const roleRow = await client.query<{ id: string }>(
    'SELECT "id" FROM "roles" WHERE "code" = $1',
    [role],
  );
  await client.query(
    `INSERT INTO "user_roles" ("user_id", "role_id", "assigned_by_user_id", "reason")
     VALUES ($1, $2, $3, 'Local acceptance fixture')`,
    [
      userId,
      roleRow.rows[0].id,
      role === 'provider_reviewer' || role === 'operations_administrator'
          ? null
          : ACCEPTANCE_IDENTITIES.reviewer.id,
    ],
  );
  if (role === 'verified_provider') {
    const applicant = await client.query<{ id: string }>(
      'SELECT "id" FROM "roles" WHERE "code" = $1',
      ['provider_applicant'],
    );
    await client.query(
      `INSERT INTO "user_roles" ("user_id", "role_id", "assigned_by_user_id", "reason")
       VALUES ($1, $2, $3, 'Local acceptance fixture')`,
      [userId, applicant.rows[0].id, ACCEPTANCE_IDENTITIES.reviewer.id],
    );
  }
}

if (require.main === module) {
  const command = process.argv[2];
  if (command !== 'seed' && command !== 'cleanup') {
    throw new Error('Usage: acceptance-fixtures.ts <seed|cleanup>');
  }
  void main(command).catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
