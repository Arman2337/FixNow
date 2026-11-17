import { MigrationInterface, QueryRunner } from 'typeorm';

export class GroupServices1789750700000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`
      CREATE TABLE group_service_requests (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        organizer_id uuid NOT NULL REFERENCES users(id),
        category_id uuid NOT NULL REFERENCES service_categories(id),
        area varchar(120) NOT NULL,
        description varchar(1000) NOT NULL,
        request_key varchar(32) NOT NULL,
        invite_token varchar(48) NOT NULL UNIQUE,
        created_at timestamptz NOT NULL DEFAULT now(),
        requested_at timestamptz,
        selected_quote_id uuid,
        UNIQUE (organizer_id, request_key),
        CHECK (selected_quote_id IS NULL OR requested_at IS NOT NULL)
      );
      CREATE INDEX ix_group_service_requests_category ON group_service_requests(category_id, created_at DESC);
      CREATE TABLE group_service_members (
        group_id uuid NOT NULL REFERENCES group_service_requests(id) ON DELETE CASCADE,
        customer_id uuid NOT NULL REFERENCES users(id),
        PRIMARY KEY (group_id, customer_id)
      );
      CREATE INDEX ix_group_service_members_customer ON group_service_members(customer_id, group_id);
      CREATE TABLE group_service_quotes (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id uuid NOT NULL REFERENCES group_service_requests(id) ON DELETE CASCADE,
        provider_id uuid NOT NULL REFERENCES users(id),
        regular_minor integer NOT NULL CHECK (regular_minor BETWEEN 2 AND 100000000),
        group_minor integer NOT NULL CHECK (group_minor > 0 AND group_minor < regular_minor),
        note varchar(500) NOT NULL,
        UNIQUE (group_id, provider_id),
        UNIQUE (group_id, id)
      );
      CREATE INDEX ix_group_service_quotes_provider ON group_service_quotes(provider_id, group_id);
      ALTER TABLE group_service_requests ADD CONSTRAINT fk_group_selected_quote
        FOREIGN KEY (id, selected_quote_id) REFERENCES group_service_quotes(group_id, id);
    `);
  }

  async down(runner: QueryRunner): Promise<void> {
    await runner.query(`
      ALTER TABLE group_service_requests DROP CONSTRAINT fk_group_selected_quote;
      DROP TABLE group_service_quotes, group_service_members, group_service_requests;
    `);
  }
}
