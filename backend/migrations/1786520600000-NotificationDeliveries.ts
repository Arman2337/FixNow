import { MigrationInterface, QueryRunner } from 'typeorm';

export class NotificationDeliveries1786520600000 implements MigrationInterface {
  name = 'NotificationDeliveries1786520600000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "notification_deliveries" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "kind" varchar(64) NOT NULL,
        "dedupe_key" varchar(200) NOT NULL,
        "booking_id" uuid,
        "status" varchar(32) NOT NULL,
        "provider_message_id" varchar(200),
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notification_deliveries" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_notification_deliveries_status"
          CHECK ("status" IN ('SENT', 'FAILED', 'NO_DEVICES', 'SKIPPED_QUIET_HOURS'))
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_notification_deliveries_dedupe" ON "notification_deliveries" ("dedupe_key", "user_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IX_notification_deliveries_user" ON "notification_deliveries" ("user_id")`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "notification_deliveries"`);
  }
}
