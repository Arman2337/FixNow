import { MigrationInterface, QueryRunner } from 'typeorm';

export class BookingReviews1786520000000 implements MigrationInterface {
  name = 'BookingReviews1786520000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "public"."review_moderation_status" AS ENUM ('PUBLISHED', 'HIDDEN', 'FLAGGED')`,
    );
    await queryRunner.query(`
      CREATE TABLE "booking_reviews" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "booking_id" uuid NOT NULL,
        "customer_id" uuid NOT NULL,
        "provider_id" uuid NOT NULL,
        "rating" smallint NOT NULL,
        "review_text" character varying(1000),
        "moderation_status" "public"."review_moderation_status" NOT NULL DEFAULT 'PUBLISHED',
        "version" integer NOT NULL DEFAULT 1,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_booking_reviews" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_booking_reviews_booking" UNIQUE ("booking_id"),
        CONSTRAINT "CHK_booking_reviews_rating" CHECK ("rating" BETWEEN 1 AND 5),
        CONSTRAINT "CHK_booking_reviews_text" CHECK ("review_text" IS NULL OR length(btrim("review_text")) BETWEEN 1 AND 1000),
        CONSTRAINT "FK_booking_reviews_booking" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT,
        CONSTRAINT "FK_booking_reviews_customer" FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE RESTRICT,
        CONSTRAINT "FK_booking_reviews_provider" FOREIGN KEY ("provider_id") REFERENCES "users"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_booking_reviews_provider_published" ON "booking_reviews" ("provider_id", "created_at" DESC) WHERE "moderation_status" = 'PUBLISHED'`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "public"."IDX_booking_reviews_provider_published"`);
    await queryRunner.query(`DROP TABLE "booking_reviews"`);
    await queryRunner.query(`DROP TYPE "public"."review_moderation_status"`);
  }
}
