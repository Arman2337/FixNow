import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * The transactional outbox.
 *
 * BUG-005. `POST /bookings` committed the booking and then, still on the request
 * thread, awaited a fan-out to up to 20 providers. Each send was three or more
 * database round-trips plus one external FCM HTTPS call per registered device,
 * so a single booking could add six seconds of third-party latency to the HTTP
 * response. The `try/catch` around it satisfied the intent ("a push failure
 * never fails a booking") but did nothing about latency.
 *
 * BUG-006. The emergency scanner ran a bare `setInterval` in every replica, so
 * three replicas did three times the work, with no leader and no re-entrancy
 * guard: up to 2,500 sequential sends per tick.
 *
 * BUG-022. A provider could be pushed the same booking twice in one wave,
 * because the ordinary and emergency paths used different dedupe keys for the
 * same underlying offer.
 *
 * All three are the same shape: work that must happen after a commit, but
 * currently runs inline, where it is neither durable nor exclusive. The outbox
 * makes the intent explicit - a row written *inside* the transaction that
 * changed the state, drained by a worker that claims rows with
 * `FOR UPDATE SKIP LOCKED`. That gives durability (a pod recycled mid-dispatch
 * loses nothing, because the row is already committed), exclusivity (only one
 * replica claims a row), and exactly-once fan-out (the dedupe key is the row's
 * unique index, so BUG-022's duplicate offer becomes a unique violation rather
 * than a design decision).
 *
 * `available_at` carries the wave schedule, so escalation timing stops being a
 * function of when a timer happened to fire and becomes a property of the row.
 */
export class TransactionalOutbox1789750200000 implements MigrationInterface {
  name = 'TransactionalOutbox1789750200000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "outbox_messages" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "kind" varchar(80) NOT NULL,
        "dedupe_key" varchar(200) NOT NULL,
        "payload" jsonb NOT NULL,
        "available_at" timestamptz NOT NULL DEFAULT now(),
        "attempts" integer NOT NULL DEFAULT 0,
        "claimed_at" timestamptz,
        "processed_at" timestamptz,
        "last_error" varchar(1000),
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_outbox_messages" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_outbox_messages_dedupe_key" UNIQUE ("dedupe_key"),
        CONSTRAINT "CHK_outbox_messages_kind" CHECK ("kind" IN (
          'booking.provider-fanout',
          'booking.project',
          'emergency.wave',
          'booking.requested-expiry',
          'booking.reminder'
        )),
        CONSTRAINT "CHK_outbox_messages_attempts" CHECK ("attempts" >= 0)
      )
    `);

    // The worker's claim query is
    //   WHERE processed_at IS NULL AND available_at <= now()
    //   ORDER BY available_at, id
    //   FOR UPDATE SKIP LOCKED
    // so the index leads on the predicate columns and carries `id` for the
    // deterministic ordering. Without it the drain is a sequential scan over
    // every row ever written, including the processed ones.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_outbox_messages_claim"
      ON "outbox_messages" ("available_at", "id")
      WHERE "processed_at" IS NULL
    `);

    // Retention sweep: a processed message is evidence that a fan-out happened,
    // but it is not the system of record (`notification_deliveries` and
    // `booking_events` are), so the table stays small.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_outbox_messages_processed"
      ON "outbox_messages" ("processed_at")
      WHERE "processed_at" IS NOT NULL
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "outbox_messages"`);
  }
}
