import { MigrationInterface, QueryRunner } from 'typeorm';

export class PaymentOrders1786520700000 implements MigrationInterface {
  name = 'PaymentOrders1786520700000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "payment_orders" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "booking_id" uuid NOT NULL,
        "customer_id" uuid NOT NULL,
        "amount_minor" integer NOT NULL,
        "currency" varchar(3) NOT NULL DEFAULT 'INR',
        "status" varchar(24) NOT NULL DEFAULT 'CREATED',
        "gateway_order_id" varchar(64) NOT NULL,
        "receipt" varchar(128) NOT NULL,
        "gateway_payment_id" varchar(64),
        "failure_reason" varchar(200),
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_payment_orders" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_payment_orders_status"
          CHECK ("status" IN ('CREATED', 'PAID', 'FAILED', 'CANCELLED'))
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_payment_orders_gateway_order" ON "payment_orders" ("gateway_order_id")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_payment_orders_receipt" ON "payment_orders" ("receipt")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IX_payment_orders_booking" ON "payment_orders" ("booking_id")`,
    );
    await queryRunner.query(`
      CREATE TABLE "payment_events" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "order_id" uuid NOT NULL,
        "event_type" varchar(64) NOT NULL,
        "payload_digest" char(64) NOT NULL,
        "actor" varchar(24) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_payment_events" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_payment_events_replay" ON "payment_events" ("order_id", "event_type", "payload_digest")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IX_payment_events_order" ON "payment_events" ("order_id")`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "payment_events"`);
    await queryRunner.query(`DROP TABLE "payment_orders"`);
  }
}
