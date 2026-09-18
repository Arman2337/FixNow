import { MigrationInterface, QueryRunner } from "typeorm";

export class UserAndBookingPhoneColumns1789747050068 implements MigrationInterface {
    name = 'UserAndBookingPhoneColumns1789747050068'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "provider_availability" ALTER COLUMN "weekly_rules" SET DEFAULT '[]'::jsonb`);
        await queryRunner.query(`ALTER TABLE "provider_availability" ALTER COLUMN "exceptions" SET DEFAULT '[]'::jsonb`);
        await queryRunner.query(`ALTER TABLE "users" ADD "phone" character varying(20)`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "phone"`);
        await queryRunner.query(`ALTER TABLE "provider_availability" ALTER COLUMN "exceptions" SET DEFAULT '[]'`);
        await queryRunner.query(`ALTER TABLE "provider_availability" ALTER COLUMN "weekly_rules" SET DEFAULT '[]'`);
    }

}
