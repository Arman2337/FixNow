import { MigrationInterface, QueryRunner } from 'typeorm';

export class OutboxMessagesUpdatedAt1789750300000 implements MigrationInterface {
  name = 'OutboxMessagesUpdatedAt1789750300000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "outbox_messages" ADD COLUMN IF NOT EXISTS "updated_at" timestamptz NOT NULL DEFAULT now()`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "outbox_messages" DROP COLUMN IF EXISTS "updated_at"`,
    );
  }
}
