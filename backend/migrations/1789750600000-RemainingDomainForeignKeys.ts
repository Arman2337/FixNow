import { MigrationInterface, QueryRunner } from 'typeorm';

/** Forward-only history repair: no old migration names or rows are rewritten.
 * NOT VALID preserves legacy orphan rows while enforcing every new write.
 * Operators can validate each constraint after inspecting any legacy orphans.
 */
export class RemainingDomainForeignKeys1789750600000 implements MigrationInterface {
  name = 'RemainingDomainForeignKeys1789750600000';

  private readonly references = [
    ['recurring_schedules', 'service_category_id', 'service_categories'],
    ['guarantee_claims', 'customer_id', 'users'],
    ['guarantee_claims', 'original_provider_id', 'users'],
    ['guarantee_claims', 'assigned_provider_id', 'users'],
    ['guarantee_claims', 're_service_booking_id', 'bookings'],
    ['review_photo_moderation_events', 'actor_user_id', 'users'],
  ] as const;

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "guarantee_claims" ADD COLUMN "version" integer NOT NULL DEFAULT 1',
    );
    for (const [table, column, parent] of this.references) {
      await queryRunner.query(
        `CREATE INDEX "ix_${table}_${column}" ON "${table}" ("${column}")`,
      );
      await queryRunner.query(
        `ALTER TABLE "${table}" ADD CONSTRAINT "fk_${table}_${column}" FOREIGN KEY ("${column}") REFERENCES "${parent}" ("id") ON DELETE RESTRICT NOT VALID`,
      );
    }
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    for (const [table, column] of [...this.references].reverse()) {
      await queryRunner.query(
        `ALTER TABLE "${table}" DROP CONSTRAINT "fk_${table}_${column}"`,
      );
      await queryRunner.query(`DROP INDEX "ix_${table}_${column}"`);
    }
    await queryRunner.query(
      'ALTER TABLE "guarantee_claims" DROP COLUMN "version"',
    );
  }
}
