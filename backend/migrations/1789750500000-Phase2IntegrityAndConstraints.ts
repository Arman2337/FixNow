import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Phase 2 Corrective Database Migration (GAP-10, GAP-11, GAP-12, GAP-15, GAP-35, GAP-36).
 *
 * 1. GAP-10: Alters FK on auth_audit_events(user_id) to ON DELETE SET NULL and ensures nullable.
 * 2. GAP-12: Adds partial unique index on booking_messages(booking_id, client_message_id) WHERE client_message_id IS NOT NULL.
 * 3. GAP-11: Adds BEFORE UPDATE trigger on complaints enforcing state transitions matching shared/complaint-lifecycle.types.ts.
 * 4. GAP-15: Adds missing FKs on recurring_schedules, guarantee_claims, and review_photo_moderation_events.
 *            Converts guarantee_claims.evidence_urls from comma-delimited text to jsonb.
 *            Ensures provider_availability.version defaults to 0.
 */
export class Phase2IntegrityAndConstraints1789750500000
  implements MigrationInterface
{
  name = 'Phase2IntegrityAndConstraints1789750500000';

  async up(queryRunner: QueryRunner): Promise<void> {
    // 1. GAP-10: auth_audit_events ON DELETE SET NULL
    await queryRunner.query(
      `ALTER TABLE "auth_audit_events" DROP CONSTRAINT IF EXISTS "fk_auth_audit_events_user"`,
    );
    await queryRunner.query(
      `ALTER TABLE "auth_audit_events" ALTER COLUMN "user_id" DROP NOT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "auth_audit_events" ADD CONSTRAINT "fk_auth_audit_events_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`,
    );

    // 2. GAP-12: partial unique index on booking_messages
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "uq_booking_messages_booking_client_msg" ON "booking_messages" ("booking_id", "client_message_id") WHERE "client_message_id" IS NOT NULL`,
    );

    // 3. GAP-11: complaints state transition trigger
    await queryRunner.query(`
      CREATE OR REPLACE FUNCTION check_complaint_status_transition()
      RETURNS TRIGGER AS $$
      BEGIN
        IF OLD.status IS NOT NULL AND OLD.status != NEW.status THEN
          IF OLD.status = 'CLOSED' THEN
            RAISE EXCEPTION 'Cannot transition from CLOSED status';
          ELSIF OLD.status = 'RESOLVED' AND NEW.status != 'CLOSED' THEN
            RAISE EXCEPTION 'Invalid status transition from RESOLVED to %', NEW.status;
          ELSIF OLD.status = 'ESCALATED' AND NEW.status NOT IN ('RESOLVED', 'CLOSED') THEN
            RAISE EXCEPTION 'Invalid status transition from ESCALATED to %', NEW.status;
          ELSIF OLD.status = 'IN_REVIEW' AND NEW.status NOT IN ('ESCALATED', 'RESOLVED', 'CLOSED') THEN
            RAISE EXCEPTION 'Invalid status transition from IN_REVIEW to %', NEW.status;
          ELSIF OLD.status = 'OPEN' AND NEW.status NOT IN ('IN_REVIEW', 'ESCALATED', 'RESOLVED', 'CLOSED') THEN
            RAISE EXCEPTION 'Invalid status transition from OPEN to %', NEW.status;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    `);
    await queryRunner.query(
      `DROP TRIGGER IF EXISTS trg_complaints_status_transition ON complaints;`,
    );
    await queryRunner.query(`
      CREATE TRIGGER trg_complaints_status_transition
      BEFORE UPDATE OF status ON complaints
      FOR EACH ROW
      EXECUTE FUNCTION check_complaint_status_transition();
    `);

    // 4. GAP-15: Missing foreign keys
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'fk_recurring_schedules_customer'
        ) THEN
          ALTER TABLE "recurring_schedules"
            ADD CONSTRAINT "fk_recurring_schedules_customer"
            FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE CASCADE;
        END IF;
      END $$;
    `);

    // Ensure guarantee_claims table and status enum exist before altering constraints
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'guarantee_claims_status_enum') THEN
          CREATE TYPE "public"."guarantee_claims_status_enum" AS ENUM('PENDING', 'IN_REVIEW', 'MORE_INFO', 'APPROVED', 'REJECTED', 'COMPLETED');
        END IF;
      END $$;
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "guarantee_claims" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "booking_id" uuid NOT NULL,
        "customer_id" uuid NOT NULL,
        "original_provider_id" uuid,
        "status" "public"."guarantee_claims_status_enum" NOT NULL DEFAULT 'PENDING',
        "description" text NOT NULL,
        "evidence_urls" text,
        "admin_notes" text,
        "assigned_provider_id" uuid,
        "re_service_booking_id" uuid,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_84abb9e309fb6ac575527a96fa0" PRIMARY KEY ("id")
      );
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'fk_guarantee_claims_booking'
        ) THEN
          ALTER TABLE "guarantee_claims"
            ADD CONSTRAINT "fk_guarantee_claims_booking"
            FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE;
        END IF;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'fk_review_photo_moderation_events_photo'
        ) THEN
          ALTER TABLE "review_photo_moderation_events"
            ADD CONSTRAINT "fk_review_photo_moderation_events_photo"
            FOREIGN KEY ("photo_id") REFERENCES "review_photos"("id") ON DELETE CASCADE;
        END IF;
      END $$;
    `);

    // GAP-15: Convert guarantee_claims.evidence_urls to jsonb
    await queryRunner.query(`
      ALTER TABLE "guarantee_claims" ALTER COLUMN "evidence_urls" TYPE jsonb USING CASE
        WHEN "evidence_urls" IS NULL OR "evidence_urls" = '' THEN '[]'::jsonb
        WHEN "evidence_urls" LIKE '[%' THEN "evidence_urls"::jsonb
        ELSE to_jsonb(string_to_array("evidence_urls", ','))
      END;
    `);

    // GAP-15: Ensure provider_availability.version defaults to 0
    await queryRunner.query(
      `ALTER TABLE "provider_availability" ALTER COLUMN "version" SET DEFAULT 0;`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP TRIGGER IF EXISTS trg_complaints_status_transition ON complaints;`,
    );
    await queryRunner.query(
      `DROP FUNCTION IF EXISTS check_complaint_status_transition();`,
    );
    await queryRunner.query(
      `ALTER TABLE "review_photo_moderation_events" DROP CONSTRAINT IF EXISTS "fk_review_photo_moderation_events_photo";`,
    );
    await queryRunner.query(
      `ALTER TABLE "guarantee_claims" DROP CONSTRAINT IF EXISTS "fk_guarantee_claims_booking";`,
    );
    await queryRunner.query(
      `ALTER TABLE "recurring_schedules" DROP CONSTRAINT IF EXISTS "fk_recurring_schedules_customer";`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "uq_booking_messages_booking_client_msg";`,
    );
    await queryRunner.query(
      `ALTER TABLE "auth_audit_events" DROP CONSTRAINT IF EXISTS "fk_auth_audit_events_user";`,
    );
    await queryRunner.query(
      `ALTER TABLE "auth_audit_events" ADD CONSTRAINT "fk_auth_audit_events_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;`,
    );
    await queryRunner.query(`
      ALTER TABLE "guarantee_claims" ALTER COLUMN "evidence_urls" TYPE text USING CASE
        WHEN "evidence_urls" IS NULL THEN NULL
        ELSE "evidence_urls"::text
      END;
    `);
  }
}
