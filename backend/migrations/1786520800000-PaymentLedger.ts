import { MigrationInterface, QueryRunner } from 'typeorm';

export class PaymentLedger1786520800000 implements MigrationInterface {
  name = 'PaymentLedger1786520800000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE SEQUENCE "invoice_number_seq" START 1`,
    );
    await queryRunner.query(`
      CREATE TABLE "refunds" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "payment_order_id" uuid NOT NULL,
        "gateway_refund_id" varchar(64) NOT NULL,
        "request_key" varchar(128),
        "amount_minor" integer NOT NULL,
        "currency" varchar(3) NOT NULL DEFAULT 'INR',
        "status" varchar(16) NOT NULL DEFAULT 'PROCESSED',
        "reason" varchar(200) NOT NULL,
        "created_by" uuid NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_refunds" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_refunds_status" CHECK ("status" IN ('PENDING', 'PROCESSED'))
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_refunds_gateway" ON "refunds" ("gateway_refund_id")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_refunds_request_key" ON "refunds" ("request_key") WHERE "request_key" IS NOT NULL`,
    );
    await queryRunner.query(
      `CREATE INDEX "IX_refunds_order" ON "refunds" ("payment_order_id")`,
    );
    await queryRunner.query(`
      CREATE TABLE "invoices" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "payment_order_id" uuid NOT NULL,
        "invoice_number" varchar(32) NOT NULL,
        "issued_at" timestamptz NOT NULL DEFAULT now(),
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_invoices" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_invoices_order" ON "invoices" ("payment_order_id")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_invoices_number" ON "invoices" ("invoice_number")`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "invoices"`);
    await queryRunner.query(`DROP TABLE "refunds"`);
    await queryRunner.query(`DROP SEQUENCE IF EXISTS "invoice_number_seq"`);
  }
}
