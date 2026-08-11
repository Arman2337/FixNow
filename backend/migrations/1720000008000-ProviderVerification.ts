import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProviderVerification1720000008000 implements MigrationInterface {
  name = 'ProviderVerification1720000008000';
  async up(queryRunner: QueryRunner): Promise<void> {
    for (const value of [
      'under_review',
      'approved',
      'rejected',
      'resubmission_requested',
    ])
      await queryRunner.query(
        `ALTER TYPE "provider_onboarding_status" ADD VALUE IF NOT EXISTS '${value}'`,
      );
    await queryRunner.query(
      `ALTER TABLE "provider_applications" ADD "assigned_reviewer_user_id" uuid, ADD "decision_reason" varchar(1000), ADD "reviewed_at" timestamptz, ADD "version" integer NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `CREATE TABLE "provider_verification_events" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "application_id" uuid NOT NULL, "actor_user_id" uuid NOT NULL, "from_status" varchar(40) NOT NULL, "to_status" varchar(40) NOT NULL, "reason" varchar(1000) NOT NULL, "application_version" integer NOT NULL, "created_at" timestamptz NOT NULL DEFAULT now(), CONSTRAINT "PK_provider_verification_events" PRIMARY KEY ("id"), CONSTRAINT "FK_provider_verification_application" FOREIGN KEY ("application_id") REFERENCES "provider_applications"("id") ON DELETE RESTRICT)`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "provider_verification_events"');
    await queryRunner.query(
      'ALTER TABLE "provider_applications" DROP COLUMN "version", DROP COLUMN "reviewed_at", DROP COLUMN "decision_reason", DROP COLUMN "assigned_reviewer_user_id"',
    );
  }
}
