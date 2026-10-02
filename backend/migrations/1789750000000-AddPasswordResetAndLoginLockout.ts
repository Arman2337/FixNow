import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Per-account login lockout and the password_reset_tokens table.
 *
 * A07 found no per-account lockout and no password-reset flow. The global
 * 5/minute throttle is keyed on the caller address (SEC-006), so it is a
 * per-address limit wearing the name of a per-account one: a shared NAT egress
 * shares one bucket, and an attacker rotating source addresses gets
 * effectively unlimited guesses against a single known email.
 *
 * `failed_login_count` and `locked_until` close that. Both live on
 * `auth_credentials` rather than a side table so the counter is updated in the
 * same statement as the credential read, and so it cannot drift out of sync
 * with the credential it protects.
 *
 * Reset tokens are stored as SHA-256 hashes, matching refresh-token handling.
 * A database disclosure must not yield a usable reset link, which would let an
 * attacker who can read the database take over any account.
 *
 * Every statement is idempotent so this is safe on a fresh replay, on a
 * database already at this schema, and on one where only part of it applied.
 */
export class AddPasswordResetAndLoginLockout1789750000000
  implements MigrationInterface
{
  name = 'AddPasswordResetAndLoginLockout1789750000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "auth_credentials"
         ADD COLUMN IF NOT EXISTS "failed_login_count" integer NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "auth_credentials"
         ADD COLUMN IF NOT EXISTS "locked_until" timestamptz`,
    );
    // A credential that is currently locked must not be silently unlocked by
    // adding the column, so the backfill is explicit rather than left to the
    // column default.
    await queryRunner.query(
      `UPDATE "auth_credentials" SET "failed_login_count" = 0
        WHERE "failed_login_count" IS NULL`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "password_reset_tokens" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "identity_id" uuid NOT NULL,
        "token_hash" varchar(64) NOT NULL,
        "expires_at" timestamptz NOT NULL,
        "consumed_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_password_reset_tokens" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_password_reset_tokens_token_hash" UNIQUE ("token_hash"),
        CONSTRAINT "FK_password_reset_tokens_identity" FOREIGN KEY ("identity_id")
          REFERENCES "user_identities"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_password_reset_tokens_identity"
         ON "password_reset_tokens" ("identity_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "public"."IDX_password_reset_tokens_identity"`,
    );
    await queryRunner.query(
      `DROP TABLE IF EXISTS "password_reset_tokens"`,
    );
    await queryRunner.query(
      `ALTER TABLE "auth_credentials" DROP COLUMN IF EXISTS "locked_until"`,
    );
    await queryRunner.query(
      `ALTER TABLE "auth_credentials" DROP COLUMN IF EXISTS "failed_login_count"`,
    );
  }
}
