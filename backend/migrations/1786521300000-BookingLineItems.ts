import { MigrationInterface, QueryRunner } from 'typeorm';

export class BookingLineItems1786521300000 implements MigrationInterface {
  name = 'BookingLineItems1786521300000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN "items" jsonb`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN "total_amount_minor" integer`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN "estimated_duration_minutes" integer`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" DROP COLUMN "estimated_duration_minutes"`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" DROP COLUMN "total_amount_minor"`,
    );
    await queryRunner.query(`ALTER TABLE "bookings" DROP COLUMN "items"`);
  }
}
