import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProviderRegistration1720000002000 implements MigrationInterface {
  name = 'ProviderRegistration1720000002000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TYPE "provider_onboarding_status" AS ENUM ('unverified')`);
    await queryRunner.query(`CREATE TABLE "provider_applications" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "user_id" uuid NOT NULL, "status" "provider_onboarding_status" NOT NULL DEFAULT 'unverified', "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_provider_applications" PRIMARY KEY ("id"), CONSTRAINT "uq_provider_applications_user_id" UNIQUE ("user_id"), CONSTRAINT "fk_provider_applications_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE)`);
    await queryRunner.query(`INSERT INTO "roles" ("id", "code", "description") VALUES ('00000000-0000-4000-8000-000000000002', 'provider_applicant', 'Unverified provider applicant') ON CONFLICT ("code") DO NOTHING`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "provider_applications"`);
    await queryRunner.query(`DELETE FROM "roles" WHERE "id" = '00000000-0000-4000-8000-000000000002' AND NOT EXISTS (SELECT 1 FROM "user_roles" WHERE "role_id" = '00000000-0000-4000-8000-000000000002')`);
    await queryRunner.query(`DROP TYPE "provider_onboarding_status"`);
  }
}
