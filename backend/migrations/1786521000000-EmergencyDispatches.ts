import { MigrationInterface, QueryRunner } from 'typeorm';

export class EmergencyDispatches1786521000000 implements MigrationInterface {
  name = 'EmergencyDispatches1786521000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "emergency_dispatches" (
        "booking_id" uuid NOT NULL,
        "current_wave" smallint NOT NULL DEFAULT 0,
        "last_escalated_at" timestamptz,
        "wave_history" jsonb NOT NULL DEFAULT '[]',
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_emergency_dispatches" PRIMARY KEY ("booking_id"),
        CONSTRAINT "CHK_emergency_wave_range" CHECK ("current_wave" BETWEEN 0 AND 3)
      )
    `);
    await queryRunner.query(`
      ALTER TABLE "emergency_dispatches"
        ADD CONSTRAINT "FK_emergency_dispatches_booking"
        FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE
    `);
    await queryRunner.query(
      `CREATE INDEX "IX_emergency_dispatches_wave" ON "emergency_dispatches" ("current_wave")`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "emergency_dispatches"`);
  }
}
