import { MigrationInterface, QueryRunner } from 'typeorm';

export class BookingModel1786519799533 implements MigrationInterface {
  name = 'BookingModel1786519799533';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "public"."booking_status" AS ENUM ('REQUESTED', 'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')`,
    );
    await queryRunner.query(`
      CREATE TABLE "bookings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "customer_id" uuid NOT NULL,
        "provider_id" uuid,
        "service_category_id" uuid NOT NULL,
        "idempotency_key" character varying(128) NOT NULL,
        "request_fingerprint" character(64) NOT NULL,
        "status" "public"."booking_status" NOT NULL DEFAULT 'REQUESTED',
        "description" character varying(2000) NOT NULL,
        "location_lat" numeric(10,7) NOT NULL,
        "location_lng" numeric(10,7) NOT NULL,
        "scheduled_at" TIMESTAMP WITH TIME ZONE,
        "assigned_at" TIMESTAMP WITH TIME ZONE,
        "en_route_at" TIMESTAMP WITH TIME ZONE,
        "started_at" TIMESTAMP WITH TIME ZONE,
        "completed_at" TIMESTAMP WITH TIME ZONE,
        "cancelled_at" TIMESTAMP WITH TIME ZONE,
        "cancellation_reason" character varying(500),
        "version" integer NOT NULL DEFAULT 1,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deleted_at" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_bookings" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_bookings_customer_idempotency" UNIQUE ("customer_id", "idempotency_key"),
        CONSTRAINT "CHK_bookings_latitude" CHECK ("location_lat" BETWEEN -90 AND 90),
        CONSTRAINT "CHK_bookings_longitude" CHECK ("location_lng" BETWEEN -180 AND 180),
        CONSTRAINT "CHK_bookings_description" CHECK (length(btrim("description")) BETWEEN 1 AND 2000),
        CONSTRAINT "CHK_bookings_cancellation" CHECK (
          ("status" = 'CANCELLED' AND "cancellation_reason" IS NOT NULL AND "cancelled_at" IS NOT NULL)
          OR ("status" <> 'CANCELLED' AND "cancellation_reason" IS NULL AND "cancelled_at" IS NULL)
        ),
        CONSTRAINT "FK_bookings_customer" FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE RESTRICT,
        CONSTRAINT "FK_bookings_provider" FOREIGN KEY ("provider_id") REFERENCES "users"("id") ON DELETE RESTRICT,
        CONSTRAINT "FK_bookings_category" FOREIGN KEY ("service_category_id") REFERENCES "service_categories"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE TABLE "booking_events" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "booking_id" uuid NOT NULL,
        "actor_user_id" uuid NOT NULL,
        "from_status" "public"."booking_status",
        "to_status" "public"."booking_status" NOT NULL,
        "reason" character varying(500),
        "booking_version" integer NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_booking_events" PRIMARY KEY ("id"),
        CONSTRAINT "FK_booking_events_booking" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_booking_events_actor" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_booking_events_booking" ON "booking_events" ("booking_id", "created_at", "id")`,
    );
    await queryRunner.query(`
      CREATE FUNCTION "prevent_booking_event_mutation"() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'booking events are immutable';
      END;
      $$ LANGUAGE plpgsql
    `);
    await queryRunner.query(`
      CREATE TRIGGER "TRG_booking_events_immutable"
      BEFORE UPDATE OR DELETE ON "booking_events"
      FOR EACH ROW EXECUTE FUNCTION "prevent_booking_event_mutation"()
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_bookings_customer_history" ON "bookings" ("customer_id", "created_at" DESC, "id" DESC) WHERE "deleted_at" IS NULL`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_bookings_provider_history" ON "bookings" ("provider_id", "created_at" DESC, "id" DESC) WHERE "deleted_at" IS NULL`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_bookings_matching" ON "bookings" ("service_category_id", "status", "created_at") WHERE "status" = 'REQUESTED' AND "deleted_at" IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP TRIGGER IF EXISTS "TRG_booking_events_immutable" ON "booking_events"`,
    );
    await queryRunner.query(
      `DROP FUNCTION IF EXISTS "prevent_booking_event_mutation"`,
    );
    await queryRunner.query(`DROP INDEX "public"."IDX_booking_events_booking"`);
    await queryRunner.query(`DROP TABLE "booking_events"`);
    await queryRunner.query(`DROP INDEX "public"."IDX_bookings_matching"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_bookings_provider_history"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_bookings_customer_history"`,
    );
    await queryRunner.query(`DROP TABLE "bookings"`);
    await queryRunner.query(`DROP TYPE "public"."booking_status"`);
  }
}
