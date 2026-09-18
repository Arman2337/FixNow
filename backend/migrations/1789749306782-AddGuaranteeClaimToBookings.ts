import { MigrationInterface, QueryRunner } from "typeorm";

export class AddGuaranteeClaimToBookings1789749306782 implements MigrationInterface {

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "is_guarantee_claim" boolean NOT NULL DEFAULT false`);
        await queryRunner.query(`ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "parent_booking_id" uuid`);
        await queryRunner.query(`ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "cancellation_reason" character varying(500)`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "bookings" DROP COLUMN "cancellation_reason"`);
        await queryRunner.query(`ALTER TABLE "bookings" DROP COLUMN "parent_booking_id"`);
        await queryRunner.query(`ALTER TABLE "bookings" DROP COLUMN "is_guarantee_claim"`);
    }

}
