import { MigrationInterface, QueryRunner } from 'typeorm';

export class TrustSafety1786520100000 implements MigrationInterface {
  name = 'TrustSafety1786520100000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TYPE "public"."trust_signal_severity" AS ENUM ('LOW', 'MEDIUM', 'HIGH')`);
    await queryRunner.query(`CREATE TYPE "public"."trust_signal_status" AS ENUM ('OPEN', 'REVIEWED', 'DISMISSED')`);
    await queryRunner.query(`CREATE TABLE "review_moderation_events" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "review_id" uuid NOT NULL, "actor_user_id" uuid NOT NULL, "from_status" "public"."review_moderation_status" NOT NULL, "to_status" "public"."review_moderation_status" NOT NULL, "reason" character varying(500) NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_review_moderation_events" PRIMARY KEY ("id"), CONSTRAINT "FK_review_moderation_events_review" FOREIGN KEY ("review_id") REFERENCES "booking_reviews"("id") ON DELETE RESTRICT, CONSTRAINT "FK_review_moderation_events_actor" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT)`);
    await queryRunner.query(`CREATE TABLE "trust_signals" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "subject_type" character varying(24) NOT NULL, "subject_id" uuid NOT NULL, "rule_code" character varying(80) NOT NULL, "window_start" character varying(32) NOT NULL, "severity" "public"."trust_signal_severity" NOT NULL, "evidence_summary" character varying(500) NOT NULL, "status" "public"."trust_signal_status" NOT NULL DEFAULT 'OPEN', "reviewed_by" uuid, "reviewed_at" TIMESTAMP WITH TIME ZONE, "version" integer NOT NULL DEFAULT 1, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_trust_signals" PRIMARY KEY ("id"), CONSTRAINT "UQ_trust_signals_subject_rule_window" UNIQUE ("subject_type", "subject_id", "rule_code", "window_start"), CONSTRAINT "FK_trust_signals_reviewer" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE RESTRICT)`);
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "trust_signals"`); await queryRunner.query(`DROP TABLE "review_moderation_events"`); await queryRunner.query(`DROP TYPE "public"."trust_signal_status"`); await queryRunner.query(`DROP TYPE "public"."trust_signal_severity"`);
  }
}
