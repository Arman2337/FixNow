import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Creates the complaints schema.
 *
 * The `complaints` and `complaint_evidence` tables exist in some developer
 * databases as artifacts of an earlier `synchronize` run, and `complaint_audits`
 * and the appeal columns were never created anywhere. Because
 * `DatabaseModule` runs with `synchronize: false` and `migrationsRun: false`,
 * nothing heals that drift automatically. This migration is therefore written
 * to converge both a fresh database and a partially-populated one onto the same
 * schema.
 */
export class ComplaintsSchema1786521300000 implements MigrationInterface {
  name = 'ComplaintsSchema1786521300000';

  async up(queryRunner: QueryRunner): Promise<void> {
    // Enum types. Postgres has no CREATE TYPE IF NOT EXISTS, and the names must
    // match TypeORM's `{table}_{column}_enum` convention or the entities will
    // read as drifted.
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "complaints_target_role_enum" AS ENUM ('PROVIDER', 'CUSTOMER', 'PLATFORM');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "complaints_status_enum" AS ENUM ('OPEN', 'IN_REVIEW', 'ESCALATED', 'RESOLVED', 'CLOSED');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "complaints_appealstatus_enum" AS ENUM ('NONE', 'PENDING', 'GRANTED', 'DENIED');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "complaint_audits_previous_status_enum" AS ENUM ('OPEN', 'IN_REVIEW', 'ESCALATED', 'RESOLVED', 'CLOSED');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "complaint_audits_new_status_enum" AS ENUM ('OPEN', 'IN_REVIEW', 'ESCALATED', 'RESOLVED', 'CLOSED');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "complaints" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "booking_id" uuid,
        "submitter_id" uuid NOT NULL,
        "target_role" "complaints_target_role_enum" NOT NULL,
        "target_id" uuid,
        "assignee_id" uuid,
        "category" varchar(100) NOT NULL,
        "description" text NOT NULL,
        "status" "complaints_status_enum" NOT NULL DEFAULT 'OPEN',
        "resolution_notes" text,
        "appealStatus" "complaints_appealstatus_enum" NOT NULL DEFAULT 'NONE',
        "appeal_reason" text,
        "appeal_resolution" text,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        "version" integer NOT NULL DEFAULT 1,
        CONSTRAINT "PK_complaints" PRIMARY KEY ("id"),
        CONSTRAINT "FK_complaints_booking" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL,
        CONSTRAINT "FK_complaints_submitter" FOREIGN KEY ("submitter_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    // Converge databases where `complaints` predates the appeal columns.
    await queryRunner.query(
      `ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "appealStatus" "complaints_appealstatus_enum" NOT NULL DEFAULT 'NONE'`,
    );
    await queryRunner.query(
      `ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "appeal_reason" text`,
    );
    await queryRunner.query(
      `ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "appeal_resolution" text`,
    );

    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IX_complaints_status" ON "complaints" ("status", "created_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IX_complaints_submitter" ON "complaints" ("submitter_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IX_complaints_booking" ON "complaints" ("booking_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IX_complaints_assignee" ON "complaints" ("assignee_id")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "complaint_evidence" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "complaint_id" uuid NOT NULL,
        "uploaded_by" uuid NOT NULL,
        "file_url" varchar(500) NOT NULL,
        "file_type" varchar(50) NOT NULL,
        "description" varchar(255),
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_complaint_evidence" PRIMARY KEY ("id"),
        CONSTRAINT "FK_complaint_evidence_complaint" FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_complaint_evidence_uploader" FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IX_complaint_evidence_complaint" ON "complaint_evidence" ("complaint_id")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "complaint_audits" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "complaint_id" uuid NOT NULL,
        "actor_id" uuid NOT NULL,
        "previous_status" "complaint_audits_previous_status_enum",
        "new_status" "complaint_audits_new_status_enum" NOT NULL,
        "notes" text,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_complaint_audits" PRIMARY KEY ("id"),
        CONSTRAINT "FK_complaint_audits_complaint" FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_complaint_audits_actor" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IX_complaint_audits_complaint" ON "complaint_audits" ("complaint_id", "created_at" DESC)`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "complaint_audits"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "complaint_evidence"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "complaints"`);
    await queryRunner.query(
      `DROP TYPE IF EXISTS "complaint_audits_new_status_enum"`,
    );
    await queryRunner.query(
      `DROP TYPE IF EXISTS "complaint_audits_previous_status_enum"`,
    );
    await queryRunner.query(`DROP TYPE IF EXISTS "complaints_appealstatus_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "complaints_status_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "complaints_target_role_enum"`);
  }
}
