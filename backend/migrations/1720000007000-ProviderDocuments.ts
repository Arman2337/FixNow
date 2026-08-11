import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProviderDocuments1720000007000 implements MigrationInterface {
  name = 'ProviderDocuments1720000007000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TABLE "provider_documents" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "document_type" varchar(40) NOT NULL, "object_key" varchar(160) NOT NULL UNIQUE, "content_type" varchar(80) NOT NULL, "size_bytes" integer NOT NULL CHECK ("size_bytes" > 0 AND "size_bytes" <= 10485760), "sha256" char(64) NOT NULL, "status" varchar(20) NOT NULL, "retention_until" timestamptz NOT NULL, "deleted_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT now(), "updated_at" timestamptz NOT NULL DEFAULT now(), CONSTRAINT "PK_provider_documents" PRIMARY KEY ("id"), CONSTRAINT "FK_provider_documents_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE)`,
    );
    await queryRunner.query(
      `CREATE TABLE "provider_document_audit_events" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "document_id" uuid NOT NULL, "actor_user_id" uuid NOT NULL, "action" varchar(30) NOT NULL, "outcome" varchar(20) NOT NULL, "created_at" timestamptz NOT NULL DEFAULT now(), CONSTRAINT "PK_provider_document_audit" PRIMARY KEY ("id"), CONSTRAINT "FK_provider_document_audit_document" FOREIGN KEY ("document_id") REFERENCES "provider_documents"("id") ON DELETE RESTRICT)`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "provider_document_audit_events"');
    await queryRunner.query('DROP TABLE "provider_documents"');
  }
}
