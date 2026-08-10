import { MigrationInterface, QueryRunner } from 'typeorm';

export class AuthTokenLifecycle1720000003000 implements MigrationInterface {
  name = 'AuthTokenLifecycle1720000003000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE "auth_sessions" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "user_id" uuid NOT NULL, "token_family_id" uuid NOT NULL, "refresh_token_hash" char(64) NOT NULL, "role" varchar(40) NOT NULL, "expires_at" timestamptz NOT NULL, "revoked_at" timestamptz, "revoke_reason" varchar(40), "replaced_by_session_id" uuid, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_auth_sessions" PRIMARY KEY ("id"), CONSTRAINT "uq_auth_sessions_refresh_token_hash" UNIQUE ("refresh_token_hash"), CONSTRAINT "fk_auth_sessions_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE)`);
    await queryRunner.query(`CREATE INDEX "ix_auth_sessions_user_id" ON "auth_sessions" ("user_id")`);
    await queryRunner.query(`CREATE INDEX "ix_auth_sessions_family_id" ON "auth_sessions" ("token_family_id")`);
    await queryRunner.query(`CREATE TABLE "otp_challenges" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "identity_id" uuid NOT NULL, "code_hash" char(64) NOT NULL, "expires_at" timestamptz NOT NULL, "resend_after" timestamptz NOT NULL, "attempts_remaining" smallint NOT NULL DEFAULT 5, "consumed_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_otp_challenges" PRIMARY KEY ("id"), CONSTRAINT "fk_otp_challenges_identity" FOREIGN KEY ("identity_id") REFERENCES "user_identities"("id") ON DELETE CASCADE)`);
    await queryRunner.query(`CREATE INDEX "ix_otp_challenges_identity_created" ON "otp_challenges" ("identity_id", "created_at")`);
    await queryRunner.query(`CREATE TABLE "auth_audit_events" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "user_id" uuid, "event_type" varchar(60) NOT NULL, "outcome" varchar(20) NOT NULL, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_auth_audit_events" PRIMARY KEY ("id"), CONSTRAINT "fk_auth_audit_events_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL)`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "auth_audit_events"`);
    await queryRunner.query(`DROP TABLE "otp_challenges"`);
    await queryRunner.query(`DROP TABLE "auth_sessions"`);
  }
}
