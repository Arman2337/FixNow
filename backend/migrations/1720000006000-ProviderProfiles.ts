import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProviderProfiles1720000006000 implements MigrationInterface {
  name = 'ProviderProfiles1720000006000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "provider_profiles" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "display_name" varchar(120) NOT NULL,
        "bio" varchar(1000),
        "service_radius_km" double precision NOT NULL,
        "base_latitude" double precision NOT NULL,
        "base_longitude" double precision NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_provider_profiles_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_provider_profiles_user_id" UNIQUE ("user_id"),
        CONSTRAINT "CHK_provider_profiles_radius" CHECK ("service_radius_km" >= 1 AND "service_radius_km" <= 100),
        CONSTRAINT "CHK_provider_profiles_latitude" CHECK ("base_latitude" >= -90 AND "base_latitude" <= 90),
        CONSTRAINT "CHK_provider_profiles_longitude" CHECK ("base_longitude" >= -180 AND "base_longitude" <= 180),
        CONSTRAINT "FK_provider_profiles_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "provider_profiles"');
  }
}
