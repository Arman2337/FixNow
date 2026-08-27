import { MigrationInterface, QueryRunner } from 'typeorm';

export class BookingMessages1786521100000 implements MigrationInterface {
  name = 'BookingMessages1786521100000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "booking_messages" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "booking_id" uuid NOT NULL,
        "sender_user_id" uuid NOT NULL,
        "sender_role" varchar(20) NOT NULL,
        "client_message_id" varchar(64),
        "message_text" text NOT NULL,
        "read_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_booking_messages" PRIMARY KEY ("id"),
        CONSTRAINT "FK_booking_messages_booking" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_booking_messages_sender" FOREIGN KEY ("sender_user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IX_booking_messages_booking_created" ON "booking_messages" ("booking_id", "created_at" ASC)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IX_booking_messages_sender" ON "booking_messages" ("sender_user_id")`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "booking_messages"`);
  }
}
