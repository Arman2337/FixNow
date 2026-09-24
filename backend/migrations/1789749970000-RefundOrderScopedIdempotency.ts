import { MigrationInterface, QueryRunner } from 'typeorm';

export class RefundOrderScopedIdempotency1789749970000 implements MigrationInterface {
  name = 'RefundOrderScopedIdempotency1789749970000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_refunds_order_request_key"
       ON "refunds" ("payment_order_id", "request_key")
       WHERE "request_key" IS NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "UQ_refunds_order_request_key"`,
    );
  }
}
