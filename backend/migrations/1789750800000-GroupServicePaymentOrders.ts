import { MigrationInterface, QueryRunner } from 'typeorm';

export class GroupServicePaymentOrders1789750800000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`
      ALTER TABLE payment_orders
        ALTER COLUMN booking_id DROP NOT NULL,
        ADD COLUMN group_service_id uuid,
        ADD CONSTRAINT "CHK_payment_orders_subject"
          CHECK (num_nonnulls(booking_id, group_service_id) = 1),
        ADD CONSTRAINT "FK_payment_orders_group_member"
          FOREIGN KEY (group_service_id, customer_id)
          REFERENCES group_service_members(group_id, customer_id);
      CREATE UNIQUE INDEX "UQ_payment_orders_group_customer"
        ON payment_orders (group_service_id, customer_id) WHERE group_service_id IS NOT NULL;
    `);
  }

  async down(runner: QueryRunner): Promise<void> {
    // SET NOT NULL deliberately refuses rollback while group orders exist.
    await runner.query(`
      ALTER TABLE payment_orders
        ALTER COLUMN booking_id SET NOT NULL,
        DROP COLUMN group_service_id;
    `);
  }
}
