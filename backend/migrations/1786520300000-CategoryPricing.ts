import { MigrationInterface, QueryRunner } from 'typeorm';

export class CategoryPricing1786520300000 implements MigrationInterface {
  name = 'CategoryPricing1786520300000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_categories" ADD COLUMN "price_amount" integer`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_categories" ADD COLUMN "price_currency" character varying(3)`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_categories" ADD CONSTRAINT "CHK_service_categories_pricing_pair" CHECK ((("price_amount" IS NULL AND "price_currency" IS NULL) OR ("price_amount" IS NOT NULL AND "price_currency" IS NOT NULL)))`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_categories" DROP CONSTRAINT "CHK_service_categories_pricing_pair"`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_categories" DROP COLUMN "price_currency"`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_categories" DROP COLUMN "price_amount"`,
    );
  }
}
