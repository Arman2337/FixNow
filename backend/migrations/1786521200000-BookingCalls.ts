import { MigrationInterface, QueryRunner } from 'typeorm';

export class BookingCalls1786521200000 implements MigrationInterface {
  name = 'BookingCalls1786521200000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "booking_calls" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "booking_id" uuid NOT NULL,
        "caller_user_id" uuid NOT NULL,
        "caller_role" varchar(20) NOT NULL,
        "callee_user_id" uuid NOT NULL,
        "status" varchar(20) NOT NULL DEFAULT 'INITIATED',
        "started_at" timestamptz NOT NULL DEFAULT now(),
        "connected_at" timestamptz,
        "ended_at" timestamptz,
        "duration_seconds" integer,
        CONSTRAINT "PK_booking_calls" PRIMARY KEY ("id"),
        CONSTRAINT "FK_booking_calls_booking" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_booking_calls_caller" FOREIGN KEY ("caller_user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_booking_calls_callee" FOREIGN KEY ("callee_user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IX_booking_calls_booking" ON "booking_calls" ("booking_id", "started_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IX_booking_calls_caller" ON "booking_calls" ("caller_user_id")`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "booking_calls"`);
  }
}
