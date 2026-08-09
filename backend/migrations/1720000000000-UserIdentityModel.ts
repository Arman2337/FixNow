import { MigrationInterface, QueryRunner } from 'typeorm';

export class UserIdentityModel1720000000000 implements MigrationInterface {
  name = 'UserIdentityModel1720000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TYPE "account_status" AS ENUM ('pending_verification', 'active', 'restricted', 'suspended', 'deactivated', 'deletion_pending', 'deleted_anonymized')`);
    await queryRunner.query(`CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "status" "account_status" NOT NULL DEFAULT 'pending_verification', "status_reason" varchar(255), "status_changed_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_users" PRIMARY KEY ("id"))`);
    await queryRunner.query(`CREATE TABLE "user_identities" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "user_id" uuid NOT NULL, "provider" varchar(64) NOT NULL, "subject" varchar(255) NOT NULL, "verified_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_user_identities" PRIMARY KEY ("id"), CONSTRAINT "uq_user_identities_provider_subject" UNIQUE ("provider", "subject"), CONSTRAINT "fk_user_identities_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE)`);
    await queryRunner.query(`CREATE INDEX "ix_user_identities_user_id" ON "user_identities" ("user_id")`);
    await queryRunner.query(`CREATE TABLE "roles" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "code" varchar(80) NOT NULL, "description" varchar(255) NOT NULL, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_roles" PRIMARY KEY ("id"), CONSTRAINT "uq_roles_code" UNIQUE ("code"))`);
    await queryRunner.query(`CREATE TABLE "user_roles" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "user_id" uuid NOT NULL, "role_id" uuid NOT NULL, "assigned_by_user_id" uuid, "reason" varchar(255) NOT NULL, "expires_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_user_roles" PRIMARY KEY ("id"), CONSTRAINT "uq_user_roles_user_role" UNIQUE ("user_id", "role_id"), CONSTRAINT "fk_user_roles_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE, CONSTRAINT "fk_user_roles_role" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT, CONSTRAINT "fk_user_roles_assigner" FOREIGN KEY ("assigned_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL)`);
    await queryRunner.query(`CREATE INDEX "ix_user_roles_user_id" ON "user_roles" ("user_id")`);
    await queryRunner.query(`CREATE INDEX "ix_user_roles_role_id" ON "user_roles" ("role_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "user_roles"`);
    await queryRunner.query(`DROP TABLE "roles"`);
    await queryRunner.query(`DROP TABLE "user_identities"`);
    await queryRunner.query(`DROP TABLE "users"`);
    await queryRunner.query(`DROP TYPE "account_status"`);
  }
}
