import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Repair migration.
 *
 * Why this exists
 * ---------------
 * `CheckSchemaSync1789749968260.up()` drops 57 named constraints and 36 indexes,
 * but only re-creates some of them (under TypeORM hash names) inside the SAME
 * `up()`. The rest appear only in `down()`. Applied forward, the database
 * permanently loses referential integrity and every value-domain check.
 *
 * It also does `ALTER TABLE "bookings" ALTER COLUMN "version" DROP DEFAULT`,
 * while `BookingsService.create()` never assigns `version` and TypeORM emits
 * the literal `DEFAULT` keyword for undefined columns. The result is an INSERT
 * against a `NOT NULL` column with no default -> SQLSTATE 23502 on every
 * booking creation.
 *
 * Every statement here is IDEMPOTENT, so this migration is safe to run against:
 *   - a database that never received CheckSchemaSync (dev/local),
 *   - a database that did receive it (any environment whose deploy runs
 *     `typeorm migration:run`, e.g. Render),
 *   - a database built from scratch by replaying every migration in order.
 *
 * Verified against the local database before writing: 47 bookings, zero rows
 * violating any of the constraints below, so no data-repair step is required.
 */
export class RestoreBookingIntegrity1789749980000 implements MigrationInterface {
  name = 'RestoreBookingIntegrity1789749980000';

  /** Constraints CheckSchemaSync drops and never restores inside up(). */
  private readonly CONSTRAINTS: ReadonlyArray<readonly [string, string, string]> = [
    // ---- bookings: referential integrity (BUG-001) ----
    [
      'bookings',
      'FK_bookings_customer',
      `ALTER TABLE "bookings" ADD CONSTRAINT "FK_bookings_customer"
         FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'bookings',
      'FK_bookings_provider',
      `ALTER TABLE "bookings" ADD CONSTRAINT "FK_bookings_provider"
         FOREIGN KEY ("provider_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'bookings',
      'FK_bookings_category',
      `ALTER TABLE "bookings" ADD CONSTRAINT "FK_bookings_category"
         FOREIGN KEY ("service_category_id") REFERENCES "service_categories"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],

    // ---- bookings: value-domain checks (BUG-001) ----
    [
      'bookings',
      'CHK_bookings_latitude',
      `ALTER TABLE "bookings" ADD CONSTRAINT "CHK_bookings_latitude"
         CHECK ("location_lat" BETWEEN -90 AND 90)`,
    ],
    [
      'bookings',
      'CHK_bookings_longitude',
      `ALTER TABLE "bookings" ADD CONSTRAINT "CHK_bookings_longitude"
         CHECK ("location_lng" BETWEEN -180 AND 180)`,
    ],
    [
      'bookings',
      'CHK_bookings_description',
      `ALTER TABLE "bookings" ADD CONSTRAINT "CHK_bookings_description"
         CHECK (length(btrim("description")) BETWEEN 1 AND 2000)`,
    ],
    [
      'bookings',
      'CHK_bookings_cancellation',
      `ALTER TABLE "bookings" ADD CONSTRAINT "CHK_bookings_cancellation" CHECK (
          ("status" = 'CANCELLED' AND "cancellation_reason" IS NOT NULL AND "cancelled_at" IS NOT NULL)
          OR ("status" <> 'CANCELLED' AND "cancellation_reason" IS NULL AND "cancelled_at" IS NULL)
        )`,
    ],
    // Defence in depth for SEC-001: even if a pricing bug is reintroduced, the
    // database refuses an out-of-range money amount.
    [
      'bookings',
      'CHK_bookings_total_amount',
      `ALTER TABLE "bookings" ADD CONSTRAINT "CHK_bookings_total_amount"
         CHECK ("total_amount_minor" IS NULL OR "total_amount_minor" BETWEEN 0 AND 10000000)`,
    ],

    // ---- other foreign keys CheckSchemaSync drops without restoring ----
    [
      'auth_audit_events',
      'fk_auth_audit_events_user',
      `ALTER TABLE "auth_audit_events" ADD CONSTRAINT "fk_auth_audit_events_user"
         FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'auth_sessions',
      'fk_auth_sessions_user',
      `ALTER TABLE "auth_sessions" ADD CONSTRAINT "fk_auth_sessions_user"
         FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'otp_challenges',
      'fk_otp_challenges_identity',
      `ALTER TABLE "otp_challenges" ADD CONSTRAINT "fk_otp_challenges_identity"
         FOREIGN KEY ("identity_id") REFERENCES "user_identities"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'booking_events',
      'FK_booking_events_actor',
      `ALTER TABLE "booking_events" ADD CONSTRAINT "FK_booking_events_actor"
         FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'provider_documents',
      'FK_provider_documents_user',
      `ALTER TABLE "provider_documents" ADD CONSTRAINT "FK_provider_documents_user"
         FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'provider_document_audit_events',
      'FK_provider_document_audit_document',
      `ALTER TABLE "provider_document_audit_events" ADD CONSTRAINT "FK_provider_document_audit_document"
         FOREIGN KEY ("document_id") REFERENCES "provider_documents"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'provider_verification_events',
      'FK_provider_verification_application',
      `ALTER TABLE "provider_verification_events" ADD CONSTRAINT "FK_provider_verification_application"
         FOREIGN KEY ("application_id") REFERENCES "provider_applications"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'user_roles',
      'fk_user_roles_assigner',
      `ALTER TABLE "user_roles" ADD CONSTRAINT "fk_user_roles_assigner"
         FOREIGN KEY ("assigned_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`,
    ],
    [
      'complaints',
      'FK_complaints_booking',
      `ALTER TABLE "complaints" ADD CONSTRAINT "FK_complaints_booking"
         FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE NO ACTION`,
    ],
    [
      'complaints',
      'FK_complaints_submitter',
      `ALTER TABLE "complaints" ADD CONSTRAINT "FK_complaints_submitter"
         FOREIGN KEY ("submitter_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`,
    ],
    [
      'complaint_evidence',
      'FK_complaint_evidence_uploader',
      `ALTER TABLE "complaint_evidence" ADD CONSTRAINT "FK_complaint_evidence_uploader"
         FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`,
    ],

    // ---- foreign keys CheckSchemaSync drops and never replaces, part 2 ----
    // These have no hash-named counterpart, so nothing else in the chain
    // brings them back once CheckSchemaSync has run.
    [
      'booking_calls',
      'FK_booking_calls_caller',
      `ALTER TABLE "booking_calls" ADD CONSTRAINT "FK_booking_calls_caller"
         FOREIGN KEY ("caller_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'booking_calls',
      'FK_booking_calls_callee',
      `ALTER TABLE "booking_calls" ADD CONSTRAINT "FK_booking_calls_callee"
         FOREIGN KEY ("callee_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'booking_messages',
      'FK_booking_messages_sender',
      `ALTER TABLE "booking_messages" ADD CONSTRAINT "FK_booking_messages_sender"
         FOREIGN KEY ("sender_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'complaint_audits',
      'FK_complaint_audits_actor',
      `ALTER TABLE "complaint_audits" ADD CONSTRAINT "FK_complaint_audits_actor"
         FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    ],
    [
      'review_moderation_events',
      'FK_review_moderation_events_review',
      `ALTER TABLE "review_moderation_events" ADD CONSTRAINT "FK_review_moderation_events_review"
         FOREIGN KEY ("review_id") REFERENCES "booking_reviews"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'review_moderation_events',
      'FK_review_moderation_events_actor',
      `ALTER TABLE "review_moderation_events" ADD CONSTRAINT "FK_review_moderation_events_actor"
         FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'booking_reviews',
      'FK_booking_reviews_booking',
      `ALTER TABLE "booking_reviews" ADD CONSTRAINT "FK_booking_reviews_booking"
         FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'booking_reviews',
      'FK_booking_reviews_customer',
      `ALTER TABLE "booking_reviews" ADD CONSTRAINT "FK_booking_reviews_customer"
         FOREIGN KEY ("customer_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'booking_reviews',
      'FK_booking_reviews_provider',
      `ALTER TABLE "booking_reviews" ADD CONSTRAINT "FK_booking_reviews_provider"
         FOREIGN KEY ("provider_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],
    [
      'trust_signals',
      'FK_trust_signals_reviewer',
      `ALTER TABLE "trust_signals" ADD CONSTRAINT "FK_trust_signals_reviewer"
         FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    ],

    // ---- other value-domain checks CheckSchemaSync drops without restoring ----
    [
      'emergency_dispatches',
      'CHK_emergency_wave_range',
      `ALTER TABLE "emergency_dispatches" ADD CONSTRAINT "CHK_emergency_wave_range"
         CHECK ("current_wave" BETWEEN 0 AND 3)`,
    ],
    [
      'provider_availability',
      'CHK_provider_availability_status',
      `ALTER TABLE "provider_availability" ADD CONSTRAINT "CHK_provider_availability_status"
         CHECK ("status" IN ('online', 'busy', 'offline'))`,
    ],
    [
      'provider_availability',
      'CHK_provider_availability_status_expiry',
      `ALTER TABLE "provider_availability" ADD CONSTRAINT "CHK_provider_availability_status_expiry" CHECK (
          ("status" = 'offline' AND "status_expires_at" IS NULL)
          OR ("status" IN ('online', 'busy') AND "status_expires_at" IS NOT NULL)
        )`,
    ],
    [
      'provider_profiles',
      'CHK_provider_profiles_latitude',
      `ALTER TABLE "provider_profiles" ADD CONSTRAINT "CHK_provider_profiles_latitude"
         CHECK ("base_latitude" BETWEEN -90 AND 90)`,
    ],
    [
      'provider_profiles',
      'CHK_provider_profiles_longitude',
      `ALTER TABLE "provider_profiles" ADD CONSTRAINT "CHK_provider_profiles_longitude"
         CHECK ("base_longitude" BETWEEN -180 AND 180)`,
    ],
    [
      'provider_profiles',
      'CHK_provider_profiles_radius',
      `ALTER TABLE "provider_profiles" ADD CONSTRAINT "CHK_provider_profiles_radius"
         CHECK ("service_radius_km" BETWEEN 1 AND 100)`,
    ],
    [
      'provider_documents',
      'provider_documents_size_bytes_check',
      `ALTER TABLE "provider_documents" ADD CONSTRAINT "provider_documents_size_bytes_check"
         CHECK ("size_bytes" > 0 AND "size_bytes" <= 10485760)`,
    ],
    [
      'notification_deliveries',
      'CHK_notification_deliveries_status',
      `ALTER TABLE "notification_deliveries" ADD CONSTRAINT "CHK_notification_deliveries_status"
         CHECK ("status" IN ('SENT', 'FAILED', 'NO_DEVICES', 'SKIPPED_QUIET_HOURS'))`,
    ],
    [
      'booking_reviews',
      'CHK_booking_reviews_text',
      `ALTER TABLE "booking_reviews" ADD CONSTRAINT "CHK_booking_reviews_text" CHECK (
          "review_text" IS NULL
          OR (length(btrim("review_text")) BETWEEN 1 AND 1000)
        )`,
    ],
    [
      'recurring_schedules',
      'CHK_recurring_schedules_cadence',
      `ALTER TABLE "recurring_schedules" ADD CONSTRAINT "CHK_recurring_schedules_cadence"
         CHECK ("cadence" IN ('WEEKLY', 'MONTHLY'))`,
    ],
    [
      'recurring_schedules',
      'CHK_recurring_schedules_status',
      `ALTER TABLE "recurring_schedules" ADD CONSTRAINT "CHK_recurring_schedules_status"
         CHECK ("status" IN ('ACTIVE', 'PAUSED', 'CANCELLED'))`,
    ],
  ];

  /** Indexes CheckSchemaSync drops without restoring, or recreates with the wrong column order. */
  private readonly INDEXES: ReadonlyArray<readonly [string, string]> = [
    [
      'IDX_bookings_customer_history',
      `CREATE INDEX IF NOT EXISTS "IDX_bookings_customer_history"
         ON "bookings" ("customer_id", "created_at" DESC, "id" DESC) WHERE "deleted_at" IS NULL`,
    ],
    [
      'IDX_bookings_provider_history',
      `CREATE INDEX IF NOT EXISTS "IDX_bookings_provider_history"
         ON "bookings" ("provider_id", "created_at" DESC, "id" DESC) WHERE "deleted_at" IS NULL`,
    ],
    [
      'IDX_bookings_matching',
      `CREATE INDEX IF NOT EXISTS "IDX_bookings_matching"
         ON "bookings" ("service_category_id", "status", "created_at")
         WHERE "status" = 'REQUESTED' AND "deleted_at" IS NULL`,
    ],
    ['IDX_booking_line_items_booking', `CREATE INDEX IF NOT EXISTS "IDX_booking_line_items_booking" ON "booking_line_items" ("booking_id")`],
    ['IDX_bookings_reminders', `CREATE INDEX IF NOT EXISTS "IDX_bookings_reminders" ON "bookings" ("scheduled_at") WHERE "status" IN ('REQUESTED', 'ASSIGNED')`],
    ['IDX_booking_events_booking', `CREATE INDEX IF NOT EXISTS "IDX_booking_events_booking" ON "booking_events" ("booking_id", "created_at", "id")`],
    ['IDX_booking_messages_booking_created', `CREATE INDEX IF NOT EXISTS "IDX_booking_messages_booking_created" ON "booking_messages" ("booking_id", "created_at")`],
    ['IDX_booking_calls_booking', `CREATE INDEX IF NOT EXISTS "IDX_booking_calls_booking" ON "booking_calls" ("booking_id", "started_at")`],
    ['IDX_emergency_dispatches_wave', `CREATE INDEX IF NOT EXISTS "IDX_emergency_dispatches_wave" ON "emergency_dispatches" ("current_wave", "created_at")`],
    ['IDX_provider_skills_user_id', `CREATE INDEX IF NOT EXISTS "IDX_provider_skills_user_id" ON "provider_skills" ("user_id")`],
    ['IDX_provider_skills_service_category_id', `CREATE INDEX IF NOT EXISTS "IDX_provider_skills_service_category_id" ON "provider_skills" ("service_category_id")`],
    ['IDX_provider_skills_is_verified', `CREATE INDEX IF NOT EXISTS "IDX_provider_skills_is_verified" ON "provider_skills" ("service_category_id", "is_verified")`],
    ['IDX_service_categories_is_active', `CREATE INDEX IF NOT EXISTS "IDX_service_categories_is_active" ON "service_categories" ("is_active")`],
    ['IDX_complaints_status', `CREATE INDEX IF NOT EXISTS "IDX_complaints_status" ON "complaints" ("status", "created_at")`],
    ['IDX_complaints_booking', `CREATE INDEX IF NOT EXISTS "IDX_complaints_booking" ON "complaints" ("booking_id")`],
    ['IDX_complaints_submitter', `CREATE INDEX IF NOT EXISTS "IDX_complaints_submitter" ON "complaints" ("submitter_id")`],
    ['IDX_complaints_assignee', `CREATE INDEX IF NOT EXISTS "IDX_complaints_assignee" ON "complaints" ("assignee_id")`],
    ['IDX_complaint_evidence_complaint', `CREATE INDEX IF NOT EXISTS "IDX_complaint_evidence_complaint" ON "complaint_evidence" ("complaint_id")`],
    ['IDX_complaint_audits_complaint', `CREATE INDEX IF NOT EXISTS "IDX_complaint_audits_complaint" ON "complaint_audits" ("complaint_id", "created_at")`],
    ['ix_auth_sessions_user_id', `CREATE INDEX IF NOT EXISTS "ix_auth_sessions_user_id" ON "auth_sessions" ("user_id")`],
    ['ix_auth_sessions_family_id', `CREATE INDEX IF NOT EXISTS "ix_auth_sessions_family_id" ON "auth_sessions" ("token_family_id")`],
    ['ix_otp_challenges_identity_created', `CREATE INDEX IF NOT EXISTS "ix_otp_challenges_identity_created" ON "otp_challenges" ("identity_id", "created_at")`],
    ['ix_user_identities_user_id', `CREATE INDEX IF NOT EXISTS "ix_user_identities_user_id" ON "user_identities" ("user_id")`],
    ['ix_user_roles_user_id', `CREATE INDEX IF NOT EXISTS "ix_user_roles_user_id" ON "user_roles" ("user_id")`],
    ['ix_user_roles_role_id', `CREATE INDEX IF NOT EXISTS "ix_user_roles_role_id" ON "user_roles" ("role_id")`],
    ['IX_push_device_tokens_user', `CREATE INDEX IF NOT EXISTS "IX_push_device_tokens_user" ON "push_device_tokens" ("user_id")`],

    // ---- unique indexes CheckSchemaSync drops with no replacement ----
    // These carry real data-integrity guarantees (one invoice per order, one
    // receipt per payment, one refund per gateway id / request key). Losing
    // them would silently allow duplicate money records.
    ['UQ_invoices_order', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_invoices_order" ON "invoices" ("payment_order_id")`],
    ['UQ_invoices_number', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_invoices_number" ON "invoices" ("invoice_number")`],
    ['UQ_payment_orders_gateway_order', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_payment_orders_gateway_order" ON "payment_orders" ("gateway_order_id")`],
    ['UQ_payment_orders_receipt', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_payment_orders_receipt" ON "payment_orders" ("receipt")`],
    ['UQ_refunds_gateway', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_refunds_gateway" ON "refunds" ("gateway_refund_id")`],
    ['UQ_refunds_request_key', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_refunds_request_key" ON "refunds" ("request_key") WHERE "request_key" IS NOT NULL`],
    ['UQ_refunds_order_request_key', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_refunds_order_request_key" ON "refunds" ("payment_order_id", "request_key") WHERE "request_key" IS NOT NULL`],
    ['UQ_review_photos_object_key', `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_review_photos_object_key" ON "review_photos" ("object_key")`],

    // ---- category ordering indexes CheckSchemaSync drops but never creates ----
    ['IDX_service_categories_display_order', `CREATE INDEX IF NOT EXISTS "IDX_service_categories_display_order" ON "service_categories" ("display_order")`],
    ['IDX_service_categories_is_emergency', `CREATE INDEX IF NOT EXISTS "IDX_service_categories_is_emergency" ON "service_categories" ("is_emergency")`],
  ];

  /** version columns CheckSchemaSync leaves NOT NULL with no default (BUG-002). */
  private readonly VERSION_COLUMNS: ReadonlyArray<readonly [string, string]> = [
    ['bookings', '1'],
    ['booking_reviews', '1'],
    ['trust_signals', '1'],
    ['complaints', '1'],
  ];

  private async addConstraintIfMissing(
    queryRunner: QueryRunner,
    table: string,
    name: string,
    ddl: string,
  ): Promise<void> {
    // `queryRunner.query` returns the rows array for a driver that reports
    // result sets (node-postgres does). Normalise so a driver that hands back a
    // full result object cannot make this look like "constraint absent".
    const result = (await queryRunner.query(
      `SELECT 1 AS present FROM pg_constraint
        WHERE conrelid = $1::regclass AND conname = $2`,
      [table, name],
    )) as unknown;
    const rows = Array.isArray(result)
      ? result
      : ((result as { rows?: unknown[] } | null)?.rows ?? []);
    if (rows.length > 0) {
      return;
    }
    await queryRunner.query(ddl);
  }

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Restore the default on every version column CheckSchemaSync stripped.
    //    Defensive: repair NULLs first so NOT NULL can be (re-)asserted safely.
    for (const [table, def] of this.VERSION_COLUMNS) {
      await queryRunner.query(
        `UPDATE "${table}" SET "version" = ${def}::integer WHERE "version" IS NULL`,
      );
      const result = (await queryRunner.query(
        `SELECT column_default FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = $1 AND column_name = 'version'`,
        [table],
      )) as unknown;
      const rows = Array.isArray(result)
        ? result
        : ((result as { rows?: unknown[] } | null)?.rows ?? []);
      if (rows.length === 0 || (rows[0] as { column_default: string | null }).column_default === null) {
        await queryRunner.query(
          `ALTER TABLE "${table}" ALTER COLUMN "version" SET DEFAULT ${def}`,
        );
      }
    }
    await queryRunner.query(
      `ALTER TABLE "invoices" ALTER COLUMN "issued_at" SET DEFAULT now()`,
    );

    // 2. Restore the dropped constraints.
    for (const [table, name, ddl] of this.CONSTRAINTS) {
      await this.addConstraintIfMissing(queryRunner, table, name, ddl);
    }

    // 3. Restore the dropped / mis-ordered indexes.
    for (const [, ddl] of this.INDEXES) {
      await queryRunner.query(ddl);
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const [table, name] of [...this.CONSTRAINTS]
      .map(([t, n]) => [t, n] as const)
      .reverse()) {
      await queryRunner.query(
        `ALTER TABLE "${table}" DROP CONSTRAINT IF EXISTS "${name}"`,
      );
    }
    for (const [name] of [...this.INDEXES].reverse()) {
      await queryRunner.query(`DROP INDEX IF EXISTS "${name}"`);
    }
    for (const [table] of this.VERSION_COLUMNS) {
      await queryRunner.query(
        `ALTER TABLE "${table}" ALTER COLUMN "version" DROP DEFAULT`,
      );
    }
    await queryRunner.query(
      `ALTER TABLE "invoices" ALTER COLUMN "issued_at" DROP DEFAULT`,
    );
  }
}
