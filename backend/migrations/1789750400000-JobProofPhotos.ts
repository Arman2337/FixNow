import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * FN-142. Before/after job proof photographs.
 *
 * Reversible: `down` drops the table, and because the booking foreign key is
 * declared ON DELETE CASCADE the rows cannot outlive their booking.
 *
 * The foreign keys are named rather than left to TypeORM's generated names,
 * because the schema gate asserts them by name and a migration that dropped
 * every bookings foreign key without restoring them is the exact failure this
 * repository already paid for once.
 */
export class JobProofPhotos1789750400000 implements MigrationInterface {
  name = 'JobProofPhotos1789750400000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "job_proof_photos" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "booking_id" uuid NOT NULL,
        "stage" varchar(8) NOT NULL,
        "uploaded_by" uuid NOT NULL,
        "object_key" varchar(512) NOT NULL,
        "content_type" varchar(100) NOT NULL,
        "size_bytes" integer NOT NULL,
        "sha256" char(64) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_job_proof_photos" PRIMARY KEY ("id"),
        CONSTRAINT "FK_job_proof_photos_booking"
          FOREIGN KEY ("booking_id") REFERENCES "bookings"("id")
          ON DELETE CASCADE,
        CONSTRAINT "FK_job_proof_photos_uploader"
          FOREIGN KEY ("uploaded_by") REFERENCES "users"("id")
          ON DELETE CASCADE,
        CONSTRAINT "CHK_job_proof_photos_stage"
          CHECK ("stage" IN ('BEFORE', 'AFTER')),
        CONSTRAINT "CHK_job_proof_photos_size" CHECK ("size_bytes" > 0)
      )
    `);
    // The object key is the storage identity; a duplicate would make one photo
    // reachable by two rows.
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_job_proof_photos_object_key" ON "job_proof_photos" ("object_key")`,
    );
    // One before and one after per booking. This is what makes "the before
    // photo" singular, and it is asserted by the schema gate.
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_job_proof_photos_booking_stage" ON "job_proof_photos" ("booking_id", "stage")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_job_proof_photos_booking" ON "job_proof_photos" ("booking_id")`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "job_proof_photos"`);
  }
}