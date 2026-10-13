/**
 * Schema integrity gate.
 *
 * Asserts the invariants that were silently lost in production: the bookings
 * foreign keys, the value-domain CHECKs, the version-column defaults, and the
 * unique indexes that make duplicate money records impossible. Every one of
 * these was dropped by a migration that never restored it, and nothing in the
 * build noticed - which is what this script exists to prevent.
 *
 * Usage:
 *   npm run schema:verify                       # uses DATABASE_URL from .env
 *   DATABASE_URL=postgres://... npm run schema:verify
 *
 * Exits non-zero on the first failed expectation, so it can gate CI.
 */
import 'dotenv/config';
import { DataSource } from 'typeorm';
import { dataSourceOptions } from '../typeorm.config';

interface Failure {
  label: string;
  detail: string;
}

class Gate {
  private readonly failures: Failure[] = [];
  private passed = 0;

  check(ok: boolean, label: string, detail = ''): void {
    if (ok) {
      this.passed += 1;
    } else {
      this.failures.push({ label, detail });
    }
  }

  get summary(): { passed: number; failed: number } {
    return { passed: this.passed, failed: this.failures.length };
  }

  report(): void {
    for (const f of this.failures) {
      console.error(`  FAIL ${f.label}${f.detail ? ` :: ${f.detail}` : ''}`);
    }
    const { passed, failed } = this.summary;
    console.log(`\n=== schema gate: ${passed} passed, ${failed} failed ===`);
  }
}

/** Constraints and indexes that a migration dropped and never restored. */
const REQUIRED_BOOKINGS_FKS = [
  'FK_bookings_customer',
  'FK_bookings_provider',
  'FK_bookings_category',
];

const REQUIRED_BOOKINGS_CHECKS = [
  'CHK_bookings_latitude',
  'CHK_bookings_longitude',
  'CHK_bookings_description',
  'CHK_bookings_cancellation',
  'CHK_bookings_total_amount',
];

/** Every `version` column must keep a default, or inserts fail outright. */
const REQUIRED_VERSION_DEFAULTS = [
  ['bookings', 'version'],
  ['booking_reviews', 'version'],
  ['trust_signals', 'version'],
  ['complaints', 'version'],
  ['invoices', 'issued_at'],
];

/**
 * Uniqueness that protects money. Losing these silently allows duplicate
 * invoices, duplicate receipts, or two refunds for one request key.
 */
const REQUIRED_UNIQUE_INDEXES = [
  'UQ_bookings_customer_idempotency',
  'UQ_invoices_order',
  'UQ_invoices_number',
  'UQ_payment_orders_gateway_order',
  'UQ_payment_orders_receipt',
  'UQ_refunds_gateway',
  'UQ_refunds_request_key',
  'UQ_refunds_order_request_key',
  'UQ_review_photos_object_key',
  // FN-142. A duplicated object key would let one photo be reachable through
  // two bookings; a duplicated (booking, stage) pair would make "the before
  // photo" ambiguous and break the customer's slider.
  'UQ_job_proof_photos_object_key',
  'UQ_job_proof_photos_booking_stage',
];

/** Foreign keys with no hash-named replacement, so nothing else restores them. */
const REQUIRED_ORPHANED_FKS: ReadonlyArray<readonly [string, string]> = [
  ['booking_calls', 'FK_booking_calls_caller'],
  ['booking_calls', 'FK_booking_calls_callee'],
  ['booking_messages', 'FK_booking_messages_sender'],
  ['complaint_audits', 'FK_complaint_audits_actor'],
  ['review_moderation_events', 'FK_review_moderation_events_review'],
  ['review_moderation_events', 'FK_review_moderation_events_actor'],
  ['booking_reviews', 'FK_booking_reviews_booking'],
  ['booking_reviews', 'FK_booking_reviews_customer'],
  ['booking_reviews', 'FK_booking_reviews_provider'],
  ['trust_signals', 'FK_trust_signals_reviewer'],
  ['provider_document_audit_events', 'FK_provider_document_audit_document'],
  ['provider_verification_events', 'FK_provider_verification_application'],
  // FN-142. Both are load-bearing: without the booking FK a proof can outlive
  // the job it describes, and without the uploader FK the "assigned provider
  // only" rule in the service stops being provable from the row.
  ['job_proof_photos', 'FK_job_proof_photos_booking'],
  ['job_proof_photos', 'FK_job_proof_photos_uploader'],
];

/** FN-142. The before/after pair is the feature; these make it singular. */
const REQUIRED_JOB_PROOF_CHECKS = [
  'CHK_job_proof_photos_stage',
  'CHK_job_proof_photos_size',
];

const REQUIRED_LOOKUP_INDEXES = [
  'IDX_service_categories_display_order',
  'IDX_service_categories_is_emergency',
];

async function main(): Promise<void> {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('DATABASE_URL is not set');
    process.exit(2);
  }

  const gate = new Gate();
  // Reuse the application's data source so this script needs no direct `pg`
  // dependency and always queries the same way the app does.
  const ds = new DataSource({
    ...(dataSourceOptions as unknown as Record<string, unknown>),
    url,
  } as never);
  await ds.initialize();
  const query = async <T>(sql: string): Promise<T[]> => await ds.query(sql);

  const target = new URL(url);
  console.log(
    `verifying schema at ${target.hostname}/${target.pathname.slice(1)}`,
  );

  const hasConstraint = async (
    table: string,
    name: string,
  ): Promise<boolean> => {
    const r = await query<{ n: number }>(
      `SELECT count(*)::int AS n FROM pg_constraint
        WHERE conrelid = '${table}'::regclass AND conname = '${name}'`,
    );
    return r[0].n > 0;
  };

  const hasIndex = async (name: string): Promise<boolean> => {
    const r = await query<{ n: number }>(
      `SELECT count(*)::int AS n FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = '${name}'`,
    );
    return r[0].n > 0;
  };

  // --- referential integrity -------------------------------------------------
  for (const name of REQUIRED_BOOKINGS_FKS) {
    gate.check(await hasConstraint('bookings', name), `fk bookings.${name}`);
  }

  // --- value domains ---------------------------------------------------------
  for (const name of REQUIRED_BOOKINGS_CHECKS) {
    gate.check(await hasConstraint('bookings', name), `check bookings.${name}`);
  }

  // --- defaults --------------------------------------------------------------
  for (const [table, column] of REQUIRED_VERSION_DEFAULTS) {
    const r = await query<{ column_default: string | null }>(
      `SELECT column_default FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = '${table}'
          AND column_name = '${column}'`,
    );
    gate.check(
      r.length > 0 && r[0].column_default !== null,
      `default ${table}.${column}`,
      r.length ? `default=${String(r[0].column_default)}` : 'column missing',
    );
  }

  // --- money integrity -------------------------------------------------------
  for (const name of REQUIRED_UNIQUE_INDEXES) {
    const r = await query<{ indexdef: string }>(
      `SELECT indexdef FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = '${name}'`,
    );
    gate.check(r.length > 0, `index ${name}`);
    const def = r[0]?.indexdef;
    if (def) {
      gate.check(
        /CREATE UNIQUE INDEX/.test(def),
        `index ${name} is UNIQUE`,
        def.slice(0, 80),
      );
    }
  }

  // --- previously orphaned constraints --------------------------------------
  for (const [table, name] of REQUIRED_ORPHANED_FKS) {
    gate.check(await hasConstraint(table, name), `fk ${table}.${name}`);
  }
  for (const name of REQUIRED_JOB_PROOF_CHECKS) {
    gate.check(
      await hasConstraint('job_proof_photos', name),
      `check job_proof_photos.${name}`,
    );
  }
  for (const name of REQUIRED_LOOKUP_INDEXES) {
    gate.check(await hasIndex(name), `index ${name}`);
  }

  // --- behaviour: the database must actually refuse bad data -----------------
  const attempt = async (
    label: string,
    sql: string,
    expectedCode: string,
  ): Promise<void> => {
    try {
      await query(sql);
      gate.check(false, label, 'insert unexpectedly succeeded');
    } catch (e) {
      const code = (e as { code?: string }).code;
      gate.check(code === expectedCode, label, `sqlstate ${code}`);
    }
  };

  // A booking for a user that does not exist must be refused.
  await attempt(
    'orphan booking refused by FK',
    `INSERT INTO bookings
       (customer_id, service_category_id, status, description,
        location_lat, location_lng, idempotency_key, request_fingerprint)
     VALUES (gen_random_uuid(), gen_random_uuid(), 'REQUESTED', 'schema gate',
             17.385, 78.4867, 'gate-orphan', 'gate-orphan-fp')`,
    '23503',
  );

  // Money outside the allowed range must be refused.
  const bookingRef = await query<{ c: string; s: string }>(
    `SELECT (SELECT id FROM users LIMIT 1) AS c,
            (SELECT id FROM service_categories LIMIT 1) AS s`,
  );
  if (bookingRef.length === 0 || !bookingRef[0].c || !bookingRef[0].s) {
    console.log(
      '\n  note: no users/service_categories seeded, skipping write checks',
    );
  } else {
    const { c, s } = bookingRef[0];
    await attempt(
      'negative total_amount_minor refused by CHECK',
      `INSERT INTO bookings
         (customer_id, service_category_id, status, description, location_lat,
          location_lng, idempotency_key, request_fingerprint, total_amount_minor)
       VALUES ('${c}', '${s}', 'REQUESTED', 'schema gate', 17.385, 78.4867,
               'gate-neg', 'gate-neg-fp', -5)`,
      '23514',
    );
    await attempt(
      'out-of-range latitude refused by CHECK',
      `INSERT INTO bookings
         (customer_id, service_category_id, status, description, location_lat,
          location_lng, idempotency_key, request_fingerprint)
       VALUES ('${c}', '${s}', 'REQUESTED', 'schema gate', 999, 78.4867,
               'gate-lat', 'gate-lat-fp')`,
      '23514',
    );

    // A valid insert that omits `version` must land on 1.
    try {
      const proof = await query<{ id: string; version: number }>(
        `INSERT INTO bookings
           (customer_id, service_category_id, status, description, location_lat,
            location_lng, idempotency_key, request_fingerprint)
         VALUES ('${c}', '${s}', 'REQUESTED', 'schema gate version default',
                 17.385, 78.4867, 'gate-ver', 'gate-ver-fp')
         RETURNING id, version`,
      );
      gate.check(
        proof.length > 0 && proof[0].version === 1,
        'insert without version yields version = 1',
        proof.length ? `got ${proof[0].version}` : 'no row returned',
      );
      if (proof.length > 0) {
        await query(`DELETE FROM bookings WHERE id = '${proof[0].id}'`);
      }
    } catch (e) {
      gate.check(
        false,
        'insert without version yields version = 1',
        (e as Error).message,
      );
    }

    // FN-142. The database itself must refuse an unknown stage, a duplicate
    // stage for the same booking, and a zero-byte photo — not merely the
    // service that happens to sit in front of it today.
    const seededBooking = await query<{ b: string }>(
      `SELECT id AS b FROM bookings WHERE customer_id = '${c}' LIMIT 1`,
    );
    if (seededBooking.length === 0) {
      const created = await query<{ b: string }>(
        `INSERT INTO bookings
           (customer_id, service_category_id, status, description, location_lat,
            location_lng, idempotency_key, request_fingerprint)
         VALUES ('${c}', '${s}', 'IN_PROGRESS', 'schema gate job proof', 17.385,
                 78.4867, 'gate-proof', 'gate-proof-fp')
         RETURNING id AS b`,
      );
      seededBooking.push(...created);
    }
    const bookingId = seededBooking[0].b;
    const proofColumns = (stage: string, key: string, size: number) =>
      `('${bookingId}', '${stage}', '${c}', '${key}', 'image/jpeg', ${size}, '${'a'.repeat(
        64,
      )}')`;

    await attempt(
      'unknown job proof stage refused by CHECK',
      `INSERT INTO job_proof_photos
         (booking_id, stage, uploaded_by, object_key, content_type, size_bytes, sha256)
       VALUES ${proofColumns('DURING', 'gate-stage-check', 10)}`,
      '23514',
    );
    await attempt(
      'zero-byte job proof photo refused by CHECK',
      `INSERT INTO job_proof_photos
         (booking_id, stage, uploaded_by, object_key, content_type, size_bytes, sha256)
       VALUES ${proofColumns('BEFORE', 'gate-size-check', 0)}`,
      '23514',
    );

    await query(
      `INSERT INTO job_proof_photos
         (booking_id, stage, uploaded_by, object_key, content_type, size_bytes, sha256)
       VALUES ${proofColumns('BEFORE', 'gate-unique-a', 10)}`,
    );
    await attempt(
      'second BEFORE photo for one booking refused by UNIQUE',
      `INSERT INTO job_proof_photos
         (booking_id, stage, uploaded_by, object_key, content_type, size_bytes, sha256)
       VALUES ${proofColumns('BEFORE', 'gate-unique-b', 10)}`,
      '23505',
    );
    // The AFTER side must still be insertable, or the unique index would be
    // over-broad and would silently forbid the second half of the feature.
    try {
      await query(
        `INSERT INTO job_proof_photos
           (booking_id, stage, uploaded_by, object_key, content_type, size_bytes, sha256)
         VALUES ${proofColumns('AFTER', 'gate-unique-after', 10)}`,
      );
      gate.check(true, 'one BEFORE and one AFTER coexist for one booking');
    } catch (e) {
      gate.check(
        false,
        'one BEFORE and one AFTER coexist for one booking',
        (e as Error).message,
      );
    }
    await query(
      `DELETE FROM job_proof_photos WHERE booking_id = '${bookingId}'`,
    );
  }

  const counts = await query(`
    SELECT
      (SELECT count(*) FROM pg_constraint c
         JOIN pg_class t ON t.oid = c.conrelid
         JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'public' AND c.contype = 'f')::int AS fks,
      (SELECT count(*) FROM pg_constraint c
         JOIN pg_class t ON t.oid = c.conrelid
         JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'public' AND c.contype = 'c')::int AS checks,
      (SELECT count(*) FROM pg_indexes
        WHERE schemaname = 'public')::int AS indexes,
      (SELECT count(*) FROM migrations)::int AS migrations`);
  console.log(`\ndb-wide: ${JSON.stringify(counts[0])}`);

  await ds.destroy();
  gate.report();
  process.exit(gate.summary.failed === 0 ? 0 : 1);
}

void main().catch((e: Error) => {
  console.error('schema gate could not run:', e.message);
  process.exit(2);
});
