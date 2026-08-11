import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProviderAvailability1720000009000 implements MigrationInterface {
  name = 'ProviderAvailability1720000009000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TABLE "provider_availability" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "time_zone" varchar(100) NOT NULL, "weekly_rules" jsonb NOT NULL DEFAULT '[]'::jsonb, "exceptions" jsonb NOT NULL DEFAULT '[]'::jsonb, "status" varchar(16) NOT NULL DEFAULT 'offline', "status_expires_at" timestamptz, "version" integer NOT NULL DEFAULT 0, "created_at" timestamptz NOT NULL DEFAULT now(), "updated_at" timestamptz NOT NULL DEFAULT now(), CONSTRAINT "UQ_provider_availability_user" UNIQUE ("user_id"), CONSTRAINT "PK_provider_availability" PRIMARY KEY ("id"), CONSTRAINT "FK_provider_availability_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE)`,
    );
    await queryRunner.query(
      `ALTER TABLE "provider_availability" ADD CONSTRAINT "CHK_provider_availability_status" CHECK ("status" IN ('online', 'busy', 'offline'))`,
    );
    await queryRunner.query(
      `ALTER TABLE "provider_availability" ADD CONSTRAINT "CHK_provider_availability_status_expiry" CHECK (("status" = 'offline' AND "status_expires_at" IS NULL) OR ("status" IN ('online', 'busy') AND "status_expires_at" IS NOT NULL))`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "provider_availability"');
  }
}
