import { MigrationInterface, QueryRunner } from 'typeorm';

export class GroupServiceEnhancements1789750900000
  implements MigrationInterface
{
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`
      ALTER TABLE group_service_requests
        ADD COLUMN IF NOT EXISTS service_address varchar(300),
        ADD COLUMN IF NOT EXISTS preferred_schedule varchar(120),
        ADD COLUMN IF NOT EXISTS service_status varchar(32) NOT NULL DEFAULT 'INVITING';

      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'chk_group_service_requests_service_status'
        ) THEN
          ALTER TABLE group_service_requests
            ADD CONSTRAINT chk_group_service_requests_service_status
            CHECK (service_status IN (
              'INVITING',
              'COLLECTING_QUOTES',
              'PROVIDER_SELECTED',
              'SCHEDULED',
              'IN_PROGRESS',
              'COMPLETED'
            ));
        END IF;
      END $$;

      UPDATE group_service_requests
      SET service_status = CASE
        WHEN selected_quote_id IS NOT NULL THEN 'PROVIDER_SELECTED'
        WHEN requested_at IS NOT NULL THEN 'COLLECTING_QUOTES'
        ELSE 'INVITING'
      END;

      ALTER TABLE group_service_members
        ADD COLUMN IF NOT EXISTS status varchar(20) NOT NULL DEFAULT 'approved',
        ADD COLUMN IF NOT EXISTS service_address varchar(300),
        ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now(),
        ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

      ALTER TABLE group_service_members
        ALTER COLUMN status SET DEFAULT 'pending';

      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'chk_group_service_members_status'
        ) THEN
          ALTER TABLE group_service_members
            ADD CONSTRAINT chk_group_service_members_status
            CHECK (status IN ('pending', 'approved', 'rejected'));
        END IF;
      END $$;

      CREATE INDEX IF NOT EXISTS ix_group_service_members_group_status
        ON group_service_members(group_id, status);
    `);
  }

  async down(runner: QueryRunner): Promise<void> {
    await runner.query(`
      DROP INDEX IF EXISTS ix_group_service_members_group_status;
      ALTER TABLE group_service_members
        DROP CONSTRAINT IF EXISTS chk_group_service_members_status,
        DROP COLUMN IF EXISTS reviewed_at,
        DROP COLUMN IF EXISTS joined_at,
        DROP COLUMN IF EXISTS service_address,
        DROP COLUMN IF EXISTS status;

      ALTER TABLE group_service_requests
        DROP CONSTRAINT IF EXISTS chk_group_service_requests_service_status,
        DROP COLUMN IF EXISTS service_status,
        DROP COLUMN IF EXISTS preferred_schedule,
        DROP COLUMN IF EXISTS service_address;
    `);
  }
}
