import { MigrationInterface, QueryRunner } from 'typeorm';

export class CustomerProfile1720000004000 implements MigrationInterface {
  name = 'CustomerProfile1720000004000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'CREATE TABLE "customer_profiles" ("user_id" uuid NOT NULL, "display_name" varchar(80) NOT NULL, "created_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, "updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "pk_customer_profiles" PRIMARY KEY ("user_id"), CONSTRAINT "fk_customer_profiles_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE)',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "customer_profiles"');
  }
}
