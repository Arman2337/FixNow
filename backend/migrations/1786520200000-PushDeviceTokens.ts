import { MigrationInterface, QueryRunner } from 'typeorm';

export class PushDeviceTokens1786520200000 implements MigrationInterface {
  name = 'PushDeviceTokens1786520200000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "public"."push_platform" AS ENUM ('ANDROID', 'IOS', 'WEB')`,
    );
    await queryRunner.query(
      `CREATE TABLE "push_device_tokens" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "platform" "public"."push_platform" NOT NULL, "token" text NOT NULL, "enabled" boolean NOT NULL DEFAULT true, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_push_device_tokens" PRIMARY KEY ("id"), CONSTRAINT "UQ_push_device_tokens_token" UNIQUE ("token"), CONSTRAINT "FK_push_device_tokens_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_push_device_tokens_user" ON "push_device_tokens" ("user_id")`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "public"."IDX_push_device_tokens_user"`);
    await queryRunner.query(`DROP TABLE "push_device_tokens"`);
    await queryRunner.query(`DROP TYPE "public"."push_platform"`);
  }
}
