/* eslint-disable */
/**
 * Standalone acceptance-fixture seeder for the LIVE local `fixnow` database.
 *
 * WHY THIS EXISTS: the official seeder (backend/test/acceptance-fixtures.ts) is
 * hard-guarded to loopback `fixnow_dev`/`fixnow_test` databases only
 * (src/auth/acceptance-fixture-guard.ts). The running dev backend and the
 * mobile/web apps authenticate against `fixnow`, where the Quick Login buttons
 * (⚡ Customer A / ⚡ Provider A) point at identities that do not exist, so both
 * quick logins401 silently. This script installs THE SAME documented
 * identities (docs/testing/local-acceptance-fixtures.md) into `fixnow` so the
 * runtime marketplace workflow can be exercised end-to-end.
 *
 * Safety properties (mirrors the official guard intent):
 *  - refuses any host except loopback;
 *  - refuses any database name except exactly `fixnow` (the local dev DB);
 *  - requires ACCEPTANCE_FIXTURES_ENABLED=true and NODE_ENV=development/test;
 *  - idempotent per identity (skips identities that already exist).
 *
 * Usage (from backend/):
 *   node scripts/seed-live-fixtures.js
 */
const { config: loadEnv } = require('dotenv');
const { join } = require('node:path');
const argon2 = require('argon2');
const { Pool } = require('pg');

loadEnv({ path: join(__dirname, '../.env') });

const IDENTITIES = {
  customerA: {
    id: '10000000-0000-4000-8000-000000000001',
    email: 'fixnow.acceptance.customer-a@local.test',
    password: 'FixNow-local-customer-a-2026!',
    role: 'customer',
  },
  providerA: {
    id: '10000000-0000-4000-8000-000000000002',
    email: 'fixnow.acceptance.provider-a@local.test',
    password: 'FixNow-local-provider-a-2026!',
    role: 'verified_provider',
  },
  providerB: {
    id: '10000000-0000-4000-8000-000000000003',
    email: 'fixnow.acceptance.provider-b@local.test',
    password: 'FixNow-local-provider-b-2026!',
    role: 'verified_provider',
  },
  reviewer: {
    id: '10000000-0000-4000-8000-000000000004',
    email: 'fixnow.acceptance.reviewer@local.test',
    password: 'FixNow-local-reviewer-2026!',
    role: 'provider_reviewer',
  },
  operationsAdmin: {
    id: '10000000-0000-4000-8000-000000000005',
    email: 'fixnow.acceptance.admin@local.test',
    password: 'FixNow-local-admin-2026!',
    role: 'operations_administrator',
  },
};

function assertSafeEnv() {
  if (!['development', 'test'].includes(process.env.NODE_ENV ?? '')) {
    throw new Error('Refusing: NODE_ENV must be development or test');
  }
  if (process.env.ACCEPTANCE_FIXTURES_ENABLED !== 'true') {
    throw new Error('Refusing: set ACCEPTANCE_FIXTURES_ENABLED=true');
  }
  const url = new URL(process.env.DATABASE_URL);
  if (!['localhost', '127.0.0.1', '::1'].includes(url.hostname)) {
    throw new Error('Refusing: host must be loopback');
  }
  if (url.pathname !== '/fixnow') {
    throw new Error(
      `Refusing: this live seeder only targets the local dev database /fixnow (got ${url.pathname})`,
    );
  }
}

async function ensureRole(client, code, description) {
  await client.query(
    'INSERT INTO "roles" ("code", "description") VALUES ($1, $2) ON CONFLICT ("code") DO NOTHING',
    [code, description],
  );
}

async function createIdentity(client, identity) {
  const existing = await client.query(
    `SELECT u."id" FROM "users" u
     JOIN "user_identities" i ON i."user_id" = u."id"
     WHERE i."subject" = $1`,
    [identity.email],
  );
  if (existing.rowCount > 0) {
    console.log(`skip (exists): ${identity.email}`);
    return;
  }
  const hash = await argon2.hash(identity.password, { type: argon2.argon2id });
  const inserted = await client.query(
    `INSERT INTO "users" ("id", "status", "status_reason")
     VALUES ($1, 'active', 'Local acceptance fixture') RETURNING "id"`,
    [identity.id],
  );
  const userId = inserted.rows[0].id;
  const identityRow = await client.query(
    `INSERT INTO "user_identities" ("user_id", "provider", "subject", "verified_at")
     VALUES ($1, 'local_email', $2, NOW()) RETURNING "id"`,
    [userId, identity.email],
  );
  await client.query(
    'INSERT INTO "auth_credentials" ("identity_id", "password_hash") VALUES ($1, $2)',
    [identityRow.rows[0].id, hash],
  );
  const roleRow = await client.query('SELECT "id" FROM "roles" WHERE "code" = $1', [
    identity.role,
  ]);
  if (roleRow.rowCount === 0) throw new Error(`Role missing: ${identity.role}`);
  await client.query(
    `INSERT INTO "user_roles" ("user_id", "role_id", "assigned_by_user_id", "reason")
     VALUES ($1, $2, $3, 'Local acceptance fixture')`,
    [
      userId,
      roleRow.rows[0].id,
      identity.role === 'provider_reviewer' || identity.role === 'operations_administrator'
        ? null
        : userId,
    ],
  );
  console.log(`created: ${identity.email} (${identity.role})`);
}

async function main() {
  assertSafeEnv();
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await ensureRole(client, 'customer', 'Customer account');
    await ensureRole(client, 'provider_applicant', 'Unverified provider applicant');
    await ensureRole(client, 'verified_provider', 'Approved provider');
    await ensureRole(client, 'provider_reviewer', 'Provider verification reviewer');
    await ensureRole(client, 'operations_administrator', 'Operations administrator');
    for (const identity of Object.values(IDENTITIES)) {
      await createIdentity(client, identity);
    }

    const reviewerId = IDENTITIES.reviewer.id;
    for (const provider of [IDENTITIES.providerA, IDENTITIES.providerB]) {
      await client.query(
        `INSERT INTO "provider_applications"
          ("user_id", "status", "assigned_reviewer_user_id", "decision_reason", "reviewed_at", "version")
         VALUES ($1, 'approved', $2, 'Local acceptance fixture', NOW(), 1)
         ON CONFLICT ("user_id") DO UPDATE SET "status" = 'approved',
           "assigned_reviewer_user_id" = $2, "decision_reason" = 'Local acceptance fixture',
           "reviewed_at" = NOW(), "version" = "provider_applications"."version" + 1`,
        [provider.id, reviewerId],
      );
    }
    await client.query(
      `INSERT INTO "provider_profiles"
        ("user_id", "display_name", "bio", "service_radius_km", "base_latitude", "base_longitude")
       VALUES ($1, 'Acceptance Provider A', 'Synthetic local fixture', 25, 22.8982000, 72.9928000),
              ($2, 'Acceptance Provider B', 'Synthetic local fixture', 5, 22.7000010, 72.8700030)
       ON CONFLICT ("user_id") DO UPDATE SET "display_name" = EXCLUDED."display_name",
         "service_radius_km" = EXCLUDED."service_radius_km",
         "base_latitude" = EXCLUDED."base_latitude", "base_longitude" = EXCLUDED."base_longitude"`,
      [IDENTITIES.providerA.id, IDENTITIES.providerB.id],
    );
    const categories = await client.query('SELECT "id" FROM "service_categories"');
    if (categories.rows.length === 0) {
      throw new Error('No service categories found; run migrations first');
    }
    for (const provider of [IDENTITIES.providerA, IDENTITIES.providerB]) {
      for (const category of categories.rows) {
        await client.query(
          `INSERT INTO "provider_skills"
            ("user_id", "service_category_id", "years_experience", "is_verified", "verification_notes")
           VALUES ($1, $2, 5, true, 'Local acceptance fixture')
           ON CONFLICT ("user_id", "service_category_id") DO UPDATE SET "is_verified" = true`,
          [provider.id, category.id],
        );
      }
      await client.query(
        `INSERT INTO "provider_availability"
          ("user_id", "time_zone", "weekly_rules", "exceptions", "status", "status_expires_at", "version")
         VALUES ($1, 'Asia/Kolkata', '[]'::jsonb, '[]'::jsonb, 'online', NOW() + INTERVAL '2 hours', 1)
         ON CONFLICT ("user_id") DO UPDATE SET "status" = 'online',
           "status_expires_at" = NOW() + INTERVAL '2 hours'`,
        [provider.id],
      );
    }
    await client.query('COMMIT');
    console.log('Acceptance fixtures installed into live local `fixnow` database.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
