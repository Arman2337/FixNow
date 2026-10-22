import type { DataSource } from 'typeorm';

/** Probe only owned, temporary fixtures; every write rolls back even on failure. */
export async function verifySchemaBehavior(
  ds: DataSource,
  gate: { check(ok: boolean, label: string, detail?: string): void },
): Promise<void> {
  const runner = ds.createQueryRunner();
  await runner.connect();
  await runner.startTransaction();
  const query = async <T>(sql: string): Promise<T[]> => await runner.query(sql);
  try {
    const attempt = async (
      label: string,
      sql: string,
      expectedCode: string,
    ): Promise<void> => {
      await query('SAVEPOINT schema_probe');
      try {
        await query(sql);
        gate.check(false, label, 'insert unexpectedly succeeded');
      } catch (e) {
        const code = (e as { code?: string }).code;
        gate.check(code === expectedCode, label, `sqlstate ${code}`);
      } finally {
        await query('ROLLBACK TO SAVEPOINT schema_probe');
        await query('RELEASE SAVEPOINT schema_probe');
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
    const [customer] = await query<{ id: string }>(
      'INSERT INTO users DEFAULT VALUES RETURNING id',
    );
    const [category] = await query<{ id: string }>(
      `INSERT INTO service_categories (name, slug) VALUES ('schema-gate-' || gen_random_uuid(), 'schema-gate-' || gen_random_uuid()) RETURNING id`,
    );
    const c = customer.id;
    const s = category.id;
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
      `INSERT INTO bookings
           (customer_id, service_category_id, status, description, location_lat,
            location_lng, idempotency_key, request_fingerprint)
         VALUES ('${c}', '${s}', 'IN_PROGRESS', 'schema gate job proof', 17.385,
                 78.4867, 'gate-proof', 'gate-proof-fp')
         RETURNING id AS b`,
    );
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
  } finally {
    await runner.rollbackTransaction();
    await runner.release();
  }
}
