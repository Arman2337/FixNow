import { MigrationInterface, QueryRunner } from 'typeorm';

export class RecurringSchedules1786520400000 implements MigrationInterface {
  name = 'RecurringSchedules1786520400000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "recurring_schedules" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "customer_id" uuid NOT NULL,
        "service_category_id" uuid NOT NULL,
        "description" varchar(2000) NOT NULL,
        "location_lat" numeric(10,7) NOT NULL,
        "location_lng" numeric(10,7) NOT NULL,
        "cadence" varchar(16) NOT NULL,
        "status" varchar(16) NOT NULL DEFAULT 'ACTIVE',
        "next_occurrence_at" timestamptz NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_recurring_schedules" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_recurring_schedules_cadence"
          CHECK ("cadence" IN ('WEEKLY', 'MONTHLY')),
        CONSTRAINT "CHK_recurring_schedules_status"
          CHECK ("status" IN ('ACTIVE', 'PAUSED', 'CANCELLED'))
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IX_recurring_schedules_customer" ON "recurring_schedules" ("customer_id")`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "recurring_schedules"`);
  }
}
