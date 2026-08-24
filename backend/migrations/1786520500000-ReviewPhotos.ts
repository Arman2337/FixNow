import { MigrationInterface, QueryRunner } from 'typeorm';

export class ReviewPhotos1786520500000 implements MigrationInterface {
  name = 'ReviewPhotos1786520500000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "review_photos" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "review_id" uuid NOT NULL,
        "uploaded_by" uuid NOT NULL,
        "object_key" varchar(512) NOT NULL,
        "content_type" varchar(100) NOT NULL,
        "size_bytes" integer NOT NULL,
        "sha256" char(64) NOT NULL,
        "status" varchar(16) NOT NULL DEFAULT 'PENDING',
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_review_photos" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_review_photos_status"
          CHECK ("status" IN ('PENDING', 'APPROVED', 'REJECTED'))
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_review_photos_object_key" ON "review_photos" ("object_key")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IX_review_photos_review" ON "review_photos" ("review_id")`,
    );
    await queryRunner.query(`
      CREATE TABLE "review_photo_moderation_events" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "photo_id" uuid NOT NULL,
        "actor_user_id" uuid NOT NULL,
        "from_status" varchar(16),
        "to_status" varchar(16) NOT NULL,
        "reason" varchar(500) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_review_photo_moderation_events" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IX_review_photo_events_photo" ON "review_photo_moderation_events" ("photo_id")`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "review_photo_moderation_events"`);
    await queryRunner.query(`DROP TABLE "review_photos"`);
  }
}
