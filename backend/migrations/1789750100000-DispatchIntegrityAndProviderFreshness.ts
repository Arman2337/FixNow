import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Three defects that only the database can close, plus the columns the code
 * needs in order to close them.
 *
 * BUG-009 - emergency abuse limits were a read-then-write
 *   `assertWithinAbuseLimits()` read the customer's last ten dispatches and
 *   threw if any was still active. Two requests with different Idempotency-Key
 *   headers both read `recent[]` before either wrote, both saw no active
 *   dispatch, and both proceeded - so one customer could hold two live
 *   emergencies, each fanning out to 50 providers and each consuming only part
 *   of the daily cap. The `Idempotency-Key` header protects against a double
 *   tap; it protects nothing against a retry loop that mints a fresh key.
 *
 *   The fix is to make the INSERT the gate. `customer_id` and `closed_at` are
 *   denormalised onto `emergency_dispatches` so a partial unique index can
 *   express "at most one open emergency per customer" without a join, and the
 *   unique violation becomes the 409.
 *
 * BUG-015 - the dispatch row was written outside the booking transaction
 *   `createEmergency()` called `bookings.create()` (which commits), and only
 *   then INSERTed the dispatch. A crash in between left a booking that no
 *   scanner would ever escalate, while the code comment claimed the opposite.
 *   `closed_at` is what makes the row self-describing: a dispatch is open until
 *   its booking reaches a terminal state, and the index needs that fact on the
 *   row itself.
 *
 * BUG-016 - provider dispatch coordinates were un-timestamped
 *   `provider_profiles` had no record of *when* a base location was set, so a
 *   profile pinned in January ranked identically to one set a second ago. The
 *   distance predicate in `matching.service.ts` consumes these coordinates and
 *   nothing else, so this column is the input to a fairness-critical decision
 *   and it needs to be auditable.
 *
 * Every statement is idempotent. The backfills are written to be safe against
 * a database that has rows, and a no-op against one that does not.
 */
export class DispatchIntegrityAndProviderFreshness1789750100000
  implements MigrationInterface
{
  name = 'DispatchIntegrityAndProviderFreshness1789750100000';

  async up(queryRunner: QueryRunner): Promise<void> {
    // ---------------------------------------------------------------- BUG-015
    // The dispatch row now carries the customer it belongs to and whether it is
    // still open, so "is this customer already in an emergency" is a property of
    // the row rather than of a join against `bookings`.
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" ADD COLUMN IF NOT EXISTS "customer_id" uuid`,
    );
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" ADD COLUMN IF NOT EXISTS "closed_at" timestamptz`,
    );
    // BUG-015, part two: `wave_history` was a read-modify-write with no
    // concurrency control, so two concurrent wave escalations silently dropped
    // one another's audit entry. `version` gives the append the same
    // compare-and-set the booking lifecycle already uses.
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" ADD COLUMN IF NOT EXISTS "version" integer NOT NULL DEFAULT 1`,
    );

    // Backfill `customer_id` from the booking each dispatch points at, and
    // close any dispatch whose booking is already terminal. Without this a
    // pre-existing row would carry a NULL customer and be invisible to the
    // new unique index.
    await queryRunner.query(`
      UPDATE "emergency_dispatches" AS dispatch
      SET "customer_id" = booking."customer_id"
      FROM "bookings" AS booking
      WHERE booking."id" = dispatch."booking_id"
        AND dispatch."customer_id" IS NULL
    `);
    await queryRunner.query(`
      UPDATE "emergency_dispatches" AS dispatch
      SET "closed_at" = COALESCE(booking."cancelled_at", booking."completed_at", dispatch."updated_at")
      FROM "bookings" AS booking
      WHERE booking."id" = dispatch."booking_id"
        AND dispatch."closed_at" IS NULL
        AND booking."status" IN ('COMPLETED', 'CANCELLED')
    `);
    // An emergency created before this migration for a booking that is still
    // live has no closure time, which is correct: it is still open.
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" ALTER COLUMN "customer_id" SET NOT NULL`,
    );
    await queryRunner.query(`
      ALTER TABLE "emergency_dispatches"
        ADD CONSTRAINT "FK_emergency_dispatches_customer"
        FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE CASCADE
    `);

    // ---------------------------------------------------------------- BUG-009
    // The gate. At most one OPEN emergency per customer, enforced by the
    // database, so two concurrent requests cannot both pass a check neither of
    // them held a lock for. A partial index is what makes this cheap and what
    // makes it correct: closed rows are excluded, so a customer may raise a new
    // emergency the moment their last one ends.
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_emergency_dispatches_active_customer"
      ON "emergency_dispatches" ("customer_id")
      WHERE "closed_at" IS NULL
    `);

    // PERF-001: the escalation scanner joins `emergency_dispatches` to
    // `bookings` filtering on `bookings.status`. `IX_emergency_dispatches_wave`
    // leads on `current_wave`, which is not the column the scan's join
    // direction needs, so the planner cannot use it. This index leads on
    // `closed_at` (the open/closed predicate) and includes `current_wave` and
    // `last_escalated_at`, which are the only other columns the scan reads.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IX_emergency_dispatches_open_scan"
      ON "emergency_dispatches" ("closed_at", "current_wave", "last_escalated_at")
      WHERE "closed_at" IS NULL
    `);

    // ---------------------------------------------------------------- BUG-014
    // BUG-014 helper: the REQUESTED sweeper needs to find bookings that nobody
    // accepted. `bookings.status` alone is not selective enough to sweep on a
    // timer, because REQUESTED also covers every healthy booking in its first
    // few seconds.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_bookings_requested_sweeper"
      ON "bookings" ("created_at")
      WHERE "status" = 'REQUESTED' AND "deleted_at" IS NULL
    `);

    // The sweeper's audit actor. `booking_events.actor_user_id` was NOT NULL
    // with a foreign key to `users`, so a transition the platform makes on its
    // own behalf had no honest way to be recorded: either a real user's id,
    // which falsely attributes the action to somebody, or a fabricated service
    // account that then has to be provisioned, rotated and audited like a
    // person.
    //
    // A null actor with an explicit `reason` is the truthful record: "no user
    // did this; here is why". Support and trust-and-safety read `reason`, and
    // `to_status`/`from_status` still carry the full lifecycle.
    await queryRunner.query(
      `ALTER TABLE "booking_events" ALTER COLUMN "actor_user_id" DROP NOT NULL`,
    );


    // ---------------------------------------------------------------- BUG-016
    // When did this dispatch base location last change? Matching ranks
    // providers on these coordinates, so a location set eight months ago was
    // being treated as exactly as live as one set a second ago - inside or
    // outside every radius, with nothing to distinguish the two cases.
    await queryRunner.query(
      `ALTER TABLE "provider_profiles" ADD COLUMN IF NOT EXISTS "base_location_updated_at" timestamptz`,
    );
    // Existing profiles are treated as freshly set: backdating them to their
    // creation time would silently remove every current provider from matching
    // on the deploy that introduces this column, which is the opposite of the
    // intent. They age out naturally over the following week instead.
    await queryRunner.query(`
      UPDATE "provider_profiles"
      SET "base_location_updated_at" = COALESCE("created_at", now())
      WHERE "base_location_updated_at" IS NULL
    `);
    // A database default as well as NOT NULL. `upsertOwnProfile` also sets
    // coordinates, from the registration form, so a column only the location
    // endpoint maintained would be null for every provider who registered that
    // way - and a NOT NULL column with no default is exactly how BUG-002 took
    // booking creation down.
    await queryRunner.query(
      `ALTER TABLE "provider_profiles" ALTER COLUMN "base_location_updated_at" SET DEFAULT now()`,
    );
    await queryRunner.query(
      `ALTER TABLE "provider_profiles" ALTER COLUMN "base_location_updated_at" SET NOT NULL`,
    );
    // BUG-001 restored the latitude/longitude range checks; this index is the
    // one the staleness predicate in `findEligibleProviders` needs.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_provider_profiles_location_freshness"
      ON "provider_profiles" ("base_location_updated_at")
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    // Any event recorded with a null actor would violate the restored NOT NULL,
    // so the down-migration refuses rather than silently deleting audit rows.
    const orphans = await queryRunner.query(
      `SELECT COUNT(*)::int AS count FROM "booking_events" WHERE "actor_user_id" IS NULL`,
    );
    const count = Number(orphans?.[0]?.count ?? 0);
    if (count > 0) {
      throw new Error(
        `Cannot revert: ${count} booking_events row(s) were recorded by the ` +
          `platform rather than a user. Delete them explicitly if that is ` +
          `really intended - they are audit history.`,
      );
    }
    await queryRunner.query(
      `ALTER TABLE "booking_events" ALTER COLUMN "actor_user_id" SET NOT NULL`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_provider_profiles_location_freshness"`,
    );
    await queryRunner.query(
      `ALTER TABLE "provider_profiles" DROP COLUMN IF EXISTS "base_location_updated_at"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_bookings_requested_sweeper"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IX_emergency_dispatches_open_scan"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "UQ_emergency_dispatches_active_customer"`,
    );
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" DROP CONSTRAINT IF EXISTS "FK_emergency_dispatches_customer"`,
    );
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" DROP COLUMN IF EXISTS "version"`,
    );
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" DROP COLUMN IF EXISTS "closed_at"`,
    );
    await queryRunner.query(
      `ALTER TABLE "emergency_dispatches" DROP COLUMN IF EXISTS "customer_id"`,
    );
  }
}
