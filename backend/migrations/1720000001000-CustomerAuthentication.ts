import { MigrationInterface, QueryRunner } from 'typeorm';

export class CustomerAuthentication1720000001000
  implements MigrationInterface
{
  name = 'CustomerAuthentication1720000001000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE "auth_credentials" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "identity_id" uuid NOT NULL, "password_hash" varchar(512) NOT NULL, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_auth_credentials" PRIMARY KEY ("id"), CONSTRAINT "uq_auth_credentials_identity_id" UNIQUE ("identity_id"), CONSTRAINT "fk_auth_credentials_identity" FOREIGN KEY ("identity_id") REFERENCES "user_identities"("id") ON DELETE CASCADE)`);
    await queryRunner.query(`INSERT INTO "roles" ("id", "code", "description") VALUES ('00000000-0000-4000-8000-000000000001', 'customer', 'Customer account') ON CONFLICT ("code") DO NOTHING`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DELETE FROM "roles" WHERE "id" = '00000000-0000-4000-8000-000000000001' AND NOT EXISTS (SELECT 1 FROM "user_roles" WHERE "role_id" = '00000000-0000-4000-8000-000000000001')`);
    await queryRunner.query(`DROP TABLE "auth_credentials"`);
  }
}
