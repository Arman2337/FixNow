# FixNow — Database Schema, Data Lifecycle & External Integrations Inventory

**Audit Date:** 2026-10-13  
**Audit Scope:** Database Entities, Constraints, Migrations, Seed Architecture, and Third-Party Integrations  
**Database Engine:** PostgreSQL 16  
**ORM:** TypeORM 0.3.x (`synchronize: false`, `migrationsRun: false`)  
**Scale:** 45 Entities, 39 Applied Migrations (+1 Orphan), 116 Indexes, 47 Foreign Keys, 23 Check Constraints  

---

## 1. Database Schema & Entity Inventory

FixNow groups its 45 persistent entities across 11 core functional domains.

### 1.1 Identity & Access Domain (8 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `users` | `User` | `id` (UUIDv4) | None | UNIQUE `email`, INDEX `account_status` | Hard delete restricted; Soft delete not present | Root identity record. Stores email, status (`pending_verification`, `active`, `suspended`, `banned`), creation date. |
| `user_identities` | `UserIdentity` | `id` (UUIDv4) | FK `user_id` -> `users.id` (1:1, CASCADE) | UNIQUE `(provider, provider_subject)` | Mutable | Stores federated login provider identities (Google, Apple). |
| `roles` | `Role` | `id` (UUIDv4) | None | UNIQUE `code` | Immutable dictionary | Contains system role definitions (`customer`, `verified_provider`, etc.). |
| `user_roles` | `UserRole` | `id` (UUIDv4) | FK `user_id` -> `users.id` (M:1), FK `role_id` -> `roles.id` (M:1) | UNIQUE `(user_id, role_id)` | CASCADE on user delete | Junction table mapping principals to system roles. |
| `auth_credentials` | `AuthCredential` | `id` (UUIDv4) | FK `user_id` -> `users.id` (1:1, CASCADE) | UNIQUE `user_id` | Sensitive boundary | Stores Argon2id password hash, failed attempt counter, lockout expiry timestamp. |
| `password_reset_tokens` | `PasswordResetToken` | `id` (UUIDv4) | FK `user_id` -> `users.id` (M:1, CASCADE) | INDEX `token_hash`, INDEX `expires_at` | TTL Expiry (1 hour) | Cryptographic 64-char reset tokens. Single-use; deleted upon consumption. |
| `customer_profiles` | `CustomerProfile` | `id` (UUIDv4) | FK `user_id` -> `users.id` (1:1, CASCADE) | UNIQUE `user_id` | Mutable | Contains customer display name, phone number, and avatar URL. |
| `customer_addresses` | `CustomerAddress` | `id` (UUIDv4) | FK `user_id` -> `users.id` (M:1, CASCADE) | INDEX `(user_id, is_default)` | CHECK lat [-90, 90], lng [-180, 180] | Saved delivery addresses with geocoded coordinates and default flag. |

### 1.2 Session & Security Domain (3 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `auth_sessions` | `AuthSession` | `id` (UUIDv4) | FK `user_id` -> `users.id` (M:1, CASCADE) | UNIQUE `refresh_token_hash`, INDEX `family_id` | TTL 30 days | Tracks active refresh tokens, IP addresses, user agents, and token family trees for replay revocation. |
| `otp_challenges` | `OtpChallenge` | `id` (UUIDv4) | None (Keyed on email) | INDEX `(email, purpose, created_at)` | TTL 10 minutes | Stores hashed 6-digit OTP codes, attempt count (max 5), and resend cooldown timestamp (60s). |
| `auth_audit_events` | `AuthAuditEvent` | `id` (UUIDv4) | FK `user_id` -> `users.id` (M:1, CASCADE) | INDEX `(user_id, created_at)` | Append-only immutable | Security audit trail recording login successes, failures, lockouts, and token refreshes. *(Risk: CASCADE erases audit trail if user is deleted, GAP-25)*. |

### 1.3 Service Catalog Domain (2 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `service_categories` | `ServiceCategory` | `id` (UUIDv4) | None | UNIQUE `slug`, INDEX `is_active` | Mutable | Top-level service domains (Plumbing, Electrical). Contains name, icon, base price minor, and emergency flag. |
| `sub_services` | `SubService` | `id` (UUIDv4) | FK `category_id` -> `service_categories.id` (M:1, RESTRICT) | INDEX `category_id`, INDEX `is_active` | Mutable | Itemized offerings with fixed unit prices (paise) and estimated durations. Re-read inside booking transaction. |

### 1.4 Provider & Verification Domain (7 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `provider_applications` | `ProviderApplication` | `id` (UUIDv4) | FK `user_id` -> `users.id` (1:1, CASCADE), FK `reviewer_id` -> `users.id` (SET NULL) | UNIQUE `user_id`, INDEX `status` | Manual CAS `version` | Onboarding lifecycle record (`unverified`, `under_review`, `approved`, `rejected`, `resubmission_requested`). |
| `provider_profiles` | `ProviderProfile` | `id` (UUIDv4) | FK `user_id` -> `users.id` (1:1, CASCADE) | UNIQUE `user_id`, INDEX `(base_lat, base_lng)` | CHECK `service_radius_km` [1, 100] | Operational technician configuration: base coordinates, service radius, bio, rating aggregate. |
| `provider_skills` | `ProviderSkill` | `id` (UUIDv4) | FK `provider_id` -> `users.id` (M:1, CASCADE), FK `category_id` -> `service_categories.id` (M:1, RESTRICT) | UNIQUE `(provider_id, category_id)` | Mutable | Declared capabilities and experience years. `is_verified` flag restricted to admin reviewers. |
| `provider_availability` | `ProviderAvailability`| `id` (UUIDv4) | FK `provider_id` -> `users.id` (1:1, CASCADE) | UNIQUE `provider_id` | Manual CAS `version` | Weekly working schedule JSON, timezone string, date exception overrides, and current operational state. |
| `provider_documents` | `ProviderDocument` | `id` (UUIDv4) | FK `application_id` -> `provider_applications.id` (M:1, CASCADE) | INDEX `(application_id, document_type)` | Soft delete `deleted_at` | Metadata for uploaded KYC credentials (ID, license, police clearance). Tracks ClamAV scan verdict. |
| `provider_document_audit_events` | `ProviderDocumentAuditEvent` | `id` (UUIDv4) | FK `document_id` -> `provider_documents.id` (M:1, CASCADE) | INDEX `document_id` | Append-only immutable | Logs document upload, download, scan pass/fail, and deletion operations. |
| `provider_verification_events` | `ProviderVerificationEvent` | `id` (UUIDv4) | FK `application_id` -> `provider_applications.id` (M:1, CASCADE) | INDEX `application_id` | Append-only immutable | Logs administrative KYC claim, approval, rejection, and resubmission requests. |

### 1.5 Booking Lifecycle Domain (8 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `bookings` | `Booking` | `id` (UUIDv4) | FK `customer_id` -> `users.id` (M:1), FK `provider_id` -> `users.id` (M:1), FK `service_category_id` -> `service_categories.id` (M:1) | INDEX `status`, INDEX `customer_id`, INDEX `provider_id`, INDEX `scheduled_at` | Optimistic `@VersionColumn`, Soft Delete `deleted_at` | Single authoritative lifecycle record. Tracks state, OTP salt, line items, timestamps, and coordinates. |
| `booking_events` | `BookingEvent` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (M:1, CASCADE) | INDEX `(booking_id, created_at)` | Append-only immutable | Authoritative state transition journal. Records actor ID, previous status, new status, and metadata. |
| `booking_line_items` | `BookingLineItem` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (M:1, CASCADE), FK `sub_service_id` -> `sub_services.id` (SET NULL) | INDEX `booking_id` | Mutable until paid | Itemized tasks attached to booking. Loaded eagerly (`eager: true`) with parent booking. |
| `booking_messages` | `BookingMessage` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (M:1, CASCADE), FK `sender_id` -> `users.id` (M:1) | INDEX `(booking_id, created_at)` | Immutable text | Two-way in-booking customer/provider chat history. *(Risk: client_message_id lacks UNIQUE index, GAP-12)*. |
| `booking_calls` | `BookingCall` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (M:1, CASCADE), FK `caller_id` -> `users.id` (M:1) | INDEX `booking_id`, INDEX `status` | Mutable | Signaled audio call sessions. Tracks `INITIATED`, `CONNECTED`, `ENDED`, and total duration seconds. |
| `job_proof_photos` | `JobProofPhoto` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (M:1, CASCADE), FK `uploaded_by_id` -> `users.id` (M:1) | INDEX `booking_id` | Immutable | Work completion proof images uploaded by technicians on site. ClamAV scanned. |
| `recurring_schedules` | `RecurringSchedule` | `id` (UUIDv4) | Soft association (No DB FK) | INDEX `user_id`, INDEX `status` | Mutable | Customer recurring maintenance subscriptions (Weekly, Bi-weekly, Monthly). *(Risk: lacks DB FK, GAP-15)*. |
| `emergency_dispatches` | `EmergencyDispatch` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (1:1, CASCADE) | UNIQUE `booking_id`, INDEX `status` | Optimistic `@VersionColumn` | Tracks SOS multi-wave radius expansion (3km -> 6km -> 12km) and targeted provider count. |

### 1.6 Payments & Financial Domain (4 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `payment_orders` | `PaymentOrder` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (M:1), FK `customer_id` -> `users.id` (M:1) | UNIQUE `gateway_order_id`, INDEX `status` | Conditional update lock | Authoritative payment record. Tracks Razorpay order ID, minor amount, currency, and escrow state. |
| `payment_events` | `PaymentEvent` | `id` (UUIDv4) | FK `order_id` -> `payment_orders.id` (M:1, CASCADE) | UNIQUE `(order_id, event_type, payload_digest)` | Append-only replay guard | Raw webhook and verification audit trail. Cryptographic digest eliminates duplicate webhook processing. |
| `refunds` | `Refund` | `id` (UUIDv4) | FK `order_id` -> `payment_orders.id` (M:1, RESTRICT) | UNIQUE `gateway_refund_id`, INDEX `order_id` | Immutable | Processed refunds issued by finance staff. Mandatory idempotency key. |
| `invoices` | `Invoice` | `id` (UUIDv4) | FK `order_id` -> `payment_orders.id` (1:1, RESTRICT) | UNIQUE `invoice_number`, UNIQUE `order_id` | Statutory immutable | Legal tax invoices. Itemizes taxable value, 18% GST (CGST + SGST), customer details, and company GSTIN. |

### 1.7 Ratings & Trust Domain (6 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `booking_reviews` | `BookingReview` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (1:1, RESTRICT), FK `provider_id` -> `users.id` (M:1) | UNIQUE `booking_id`, INDEX `provider_id` | Optimistic `@VersionColumn` | Customer 1-5 star ratings and reviews. Subject to staff moderation (`PENDING`, `APPROVED`, `REJECTED`). |
| `review_photos` | `ReviewPhoto` | `id` (UUIDv4) | FK `review_id` -> `booking_reviews.id` (M:1, CASCADE) | INDEX `review_id` | Mutable | Photos attached to reviews. Quarantined until ClamAV and staff moderation approve. |
| `review_moderation_events` | `ReviewModerationEvent` | `id` (UUIDv4) | FK `review_id` -> `booking_reviews.id` (M:1, CASCADE) | INDEX `review_id` | Append-only immutable | Logs moderator identity, action (`APPROVE`/`REJECT`), and justification notes. |
| `review_photo_moderation_events` | `ReviewPhotoModerationEvent` | `id` (UUIDv4) | Soft association (No DB FK) | INDEX `photo_id` | Append-only immutable | Logs moderation actions on individual review photos. *(Risk: lacks DB FK, GAP-15)*. |
| `trust_signals` | `TrustSignal` | `id` (UUIDv4) | FK `provider_id` -> `users.id` (M:1, CASCADE) | INDEX `(provider_id, signal_type)` | Optimistic `@VersionColumn` | Automated trust risk scores (e.g., repeated cancellations, excessive OTP retries, rapid job completions). |
| `guarantee_claims` | `GuaranteeClaim` | `id` (UUIDv4) | Soft association (No DB FK) | INDEX `booking_id`, INDEX `status` | Mutable | Formal 30-day warranty claims filed by customers. Contains description and serialized evidence URLs. *(Risk: lacks DB FK, GAP-15)*. |

### 1.8 Support & Customer Care Domain (3 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `complaints` | `Complaint` | `id` (UUIDv4) | FK `booking_id` -> `bookings.id` (M:1), FK `submitter_id` -> `users.id` (M:1, SET NULL) | INDEX `status`, INDEX `submitter_id` | Optimistic `@VersionColumn` | Customer complaints and billing disputes. Follows formal multi-stage adjudication lifecycle. |
| `complaint_evidence` | `ComplaintEvidence` | `id` (UUIDv4) | FK `complaint_id` -> `complaints.id` (M:1, CASCADE) | INDEX `complaint_id` | Immutable | Attached images and receipts supporting the complaint. |
| `complaint_audits` | `ComplaintAudit` | `id` (UUIDv4) | FK `complaint_id` -> `complaints.id` (M:1, CASCADE) | INDEX `complaint_id` | Append-only immutable | Complete history of status changes, agent assignments, and resolution notes. |

### 1.9 Notifications & Device Management Domain (3 Entities)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `in_app_notifications` | `InAppNotification` | `id` (UUIDv4) | FK `user_id` -> `users.id` (M:1, CASCADE) | INDEX `(user_id, read_at)` | Soft read flag | Inbox feed notifications displayed in customer and provider app notification centers. |
| `notification_deliveries` | `NotificationDelivery` | `id` (UUIDv4) | FK `notification_id` -> `in_app_notifications.id` (M:1, CASCADE) | INDEX `notification_id` | Immutable | Delivery attempt logs across email, SMS, and push channels. Tracks provider message IDs. |
| `push_device_tokens` | `PushDeviceToken` | `id` (UUIDv4) | FK `user_id` -> `users.id` (M:1, CASCADE) | UNIQUE `(user_id, token)` | Upsert on login | Hardware FCM push tokens registered by iOS, Android, and Web clients. |

### 1.10 Operational Outbox Engine (1 Entity)

| Table Name | Entity Class | Primary Key | Foreign Keys & Cardinality | Indexes & Unique Constraints | Concurrency & Lifecycle | Purpose & Data Retention |
|---|---|---|---|---|---|---|
| `outbox_messages` | `OutboxMessage` | `id` (UUIDv4) | None | UNIQUE `dedupe_key`, INDEX `(status, scheduled_at)` | Row-level lease locking | Transactional outbox table. Guarantees at-least-once asynchronous event delivery. Claimed using `pessimistic_write`. |

---

## 2. Migration History & Schema Integrity Audit

- **Migration Engine:** TypeORM CLI. All migrations reside in `backend/migrations/`.
- **Total Applied Migrations:** 39 migration files.
- **Verification Gates:**
  - `npm run schema:verify`: Executed against current local PostgreSQL database -> **54/54 checks passed (0 errors)**.
  - `npm run schema:verify:fresh`: Executed against scratch database (`fixnow_schema_gate`) -> **61/61 checks passed (0 errors)**.
- **Critical Migration Findings & Historical Anomalies:**
  1. **Orphan Migration File (`GAP-08`):** `backend/src/database/migrations/1789735751504-add-phone-to-users.ts` exists outside the configured migration glob (`backend/migrations/`). It is never executed by TypeORM. Its intended schema change (`phone_number` on `users`) was separately applied by migration `1789748288429`. Attempting to run this orphan would crash with PostgreSQL error `42701 duplicate_column`.
  2. **Duplicate Timestamp Collision (`GAP-09`):** Timestamp `1786521300000` is shared by two distinct migration files (`1786521300000-BookingLineItems.ts` and `1786521300000-ComplaintsSchema.ts`). While TypeORM differentiates them by class name, their relative execution ordering is filesystem-dependent.
  3. **Foreign Key Cascade Drift on Users (`GAP-25`):** In `1789749980000-RestoreBookingIntegrity.ts`, the foreign key on `auth_audit_events.user_id` was modified to `ON DELETE CASCADE`. As a result, deleting a user completely purges their authentication security audit trail, violating compliance standards.

---

## 3. Seed Architecture & Deploy Safety

- **Production Seed Entry:** `backend/seed.js` is invoked on container initialization via `render.yaml:7`.
- **Deploy Safety Remediation (GAP-02):**
  - Previously, `seed.js` executed an unconstrained `DELETE FROM sub_services`, completely wiping out all custom, admin-configured sub-services on every application deploy.
  - Remediated to non-destructive insertion using `INSERT INTO sub_services ... WHERE NOT EXISTS (...)`. Existing custom services and prices are preserved across deployments.
  - Added regression test suite `backend/src/services/catalog-seed.spec.ts` (9 passing tests).
- **Test Fixture Seeding:**
  - Handled by `backend/test/acceptance-fixtures.ts`.
  - Guarded by strict environment gates: requires `NODE_ENV ∈ {'development', 'test'}`, `ACCEPTANCE_FIXTURES_ENABLED=true`, and loopback database connection host.

---

## 4. Comprehensive Integrations & Infrastructure Inventory

FixNow interfaces with 13 third-party services, adapters, and infrastructure systems.

| Integration | Functional Purpose | Integration Boundary / Adapter File | Required Configuration Variables (Names Only) | Data Transmitted / Received | Auth & Signature Verification | Failure & Fallback Behavior |
|---|---|---|---|---|---|---|
| **Razorpay Payment Gateway** | Order creation, customer payment collection, refunds | `backend/src/payments/gateways/razorpay.gateway.ts` | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` | Out: minor amounts, receipt ID; In: payment IDs, signatures, statuses | Cryptographic HMAC-SHA256 signature verification over raw body buffer | 3 retries on network failure; webhook replay guard via digest |
| **Google Gemini 1.5 Flash Vision** | Multimodal image and combined problem classification | `backend/src/ai/problem-classification/gemini-vision.adapter.ts` | `GEMINI_API_KEY`, `GEMINI_MODEL_VERSION` | Out: image buffers (<=32 MiB), scene prompt; In: JSON classification & confidence | API Bearer Token | Advisory-only fallback; failure returns generic category suggestion |
| **Speech-to-Text Adapter** | Voice recording transcription | `backend/src/ai/problem-classification/speech-to-text.adapter.ts` | `SPEECH_TO_TEXT_API_KEY`, `SPEECH_TO_TEXT_SERVICE_URL` | Out: audio streams (m4a, wav <=50 MiB); In: text transcript | Mutual TLS / API Token | If service fails, prompts user to type description manually |
| **Firebase Cloud Messaging (FCM)** | Mobile push notification delivery | `backend/src/notifications/push/fcm-push.adapter.ts` | `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` | Out: push payloads, device tokens, notification badges; In: FCM message ID | Google Service Account OAuth2 JWT | Enqueued via Outbox; invalid tokens pruned automatically |
| **ClamAV Antivirus Daemon** | Malware scanning on uploaded KYC documents and photos | `backend/src/storage/clamav-malware-scanner.ts` | `CLAMAV_HOST`, `CLAMAV_PORT`, `CLAMAV_TIMEOUT_MS` | Out: file binary stream (`INSTREAM`); In: `OK` or `FOUND <virus_name>` | TCP Socket Protocol (no auth) | Fails closed: documents remain quarantined if ClamAV daemon is unreachable |
| **AWS S3 / Compatible Object Storage** | Encrypted private storage for KYC documents and proof photos | `backend/src/storage/s3-private-object-storage.ts` | `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET_NAME`, `S3_ENDPOINT` | Out: multipart binary streams; In: S3 object keys, ETags | AWS Signature Version 4 (SigV4) | Retries 3 times with exponential backoff; pre-signed URLs (15 min TTL) |
| **OpenStreetMap & Nominatim** | Map tile rendering and reverse geocoding | `mobile/lib/features/tracking/provider_live_map.dart` | `OSM_TILE_SERVER_URL` | Out: tile coordinates `{z}/{x}/{y}`; In: PNG tile rasters | Public Open Source / Custom User-Agent | Caches raster tiles locally; warns if rate limited |
| **BigDataCloud Geocoding** | Client-side mobile reverse geocoding fallback | `mobile/lib/core/location/geocoding_service.dart` | `BIGDATACLOUD_API_KEY` | Out: GPS coordinates (lat, lng); In: locality, city, postal code | API Query Key | Falls back to device native Android/iOS geocoder if unreachable |
| **PostgreSQL 16** | Authoritative relational ACID persistence | `backend/src/database/database.module.ts` | `DATABASE_URL`, `DB_POOL_MIN`, `DB_POOL_MAX`, `DB_IDLE_TIMEOUT_MS` | Out: SQL queries; In: rowsets | Password auth / SSL (`rejectUnauthorized: true` in prod) | Connection pool health pings every 3s; 503 on readiness probe |
| **Redis 7 Cluster / Standalone** | Distributed caching, rate limit storage, realtime pub/sub | `backend/src/cache/redis-cache.service.ts` | `REDIS_URL`, `REDIS_TTL_DEFAULT` | Out: key-value pairs, pub/sub frames; In: cached JSON | Redis AUTH / TLS | Sentinel health monitor every 10s; gracefully degrades to in-process EventEmitter |
| **Resend / SMTP Mailer** | Transactional email delivery for OTPs and reset tokens | `backend/src/notifications/mail/mail.service.ts` | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `MAIL_FROM` | Out: HTML email bodies, recipient addresses; In: transmission receipt | TLS / SMTP Auth | 30s timeout; logs failure to audit table |
| **Prometheus Metrics Scraper**| Application runtime metrics and OpenMetrics exposition | `backend/src/observability/metrics.controller.ts` | `METRICS_ENABLED`, `PROMETHEUS_METRIC_PREFIX` | Out: OpenMetrics exposition text format; In: HTTP scrape requests | IP Allowlist / Public `/health/metrics` | In-memory atomic counters; zero DB overhead |
| **Render Cloud Platform** | Managed application hosting and container orchestration | `render.yaml` | `PORT`, `NODE_ENV`, `DATABASE_URL` | Infrastructure orchestration | Platform Managed Credentials | Graceful shutdown hooks drain active HTTP and WS connections |
