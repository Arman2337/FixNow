# FixNow — Completeness Audit, Gaps & Technical Debt Register

**Audit Date:** 2026-10-13  
**Audit Scope:** Repository-Wide Defect Verification, Dead Code Analysis, and Gap Traceability  
**Baseline Commit:** `d9951c4` + Phase 1 Remediation (`seed.js`, `scan-secrets.mjs`, `catalog-seed.spec.ts`)  
**Total Verified Findings:** 89 Items (`GAP-01` through `GAP-89`)  
**Severity Taxonomy:**  
- **P0 (Critical / Blocker):** Production data loss, CI pipeline failures, or workflow corruption.
- **P1 (High):** Security vulnerabilities, authorization bypasses, compliance breaches, route shadowing, and broken core flows.
- **P2 (Medium):** Incomplete paths, unpaginated large datasets, orphaned screens, client-server contract drift, and unwired modules.
- **P3 (Low / Polish):** Cosmetic mismatches, dead native code, redundant helpers, and unreferenced design system widgets.

---

## 1. Executive Summary & Defect Landscape

| Severity Category | Total Identified | Remediated in Current Audit | Open / Pending |
|---|---|---|---|
| **P0 — Critical Blockers** | 3 | 2 (`GAP-01`, `GAP-02`) | 1 (`GAP-03`) |
| **P1 — High Severity** | 22 | 0 | 22 |
| **P2 — Medium Severity** | 42 | 0 | 42 |
| **P3 — Low Severity** | 22 | 0 | 22 |
| **Total Findings** | **89** | **2** | **87** |

---

## 2. P0 — Critical Defects & Production Blockers

### `GAP-01` · CI Pipeline Blocker: Secret Scanner Fails on Committed Test Fixture
- **Location:** `backend/src/health/health-dashboard.spec.ts:173`, `.github/workflows/ci.yml:342`, `scripts/scan-secrets.mjs`
- **Impact:** False-positive match on a synthetic PostgreSQL connection string (`ECONNREFUSED` error fixture for non-resolving host `db.internal`). Blocked the entire GitHub Actions `Secrets` CI gate with exit code 1.
- **Remediation Status:** `RESOLVED & VERIFIED`. Added `# scan-secrets: allow postgres-url-with-password -- test fixture` inline marker; `node scripts/scan-secrets.mjs` returns 0 findings on 1,721 blobs. Self-test passed (11/11).

### `GAP-02` · Production Data Loss: `seed.js` Purges Sub-Services on Every Deployment
- **Location:** `backend/seed.js:91`, `render.yaml:7`
- **Impact:** `render.yaml` executes `migration:run && node seed.js && start:prod` on every deployment container start. `seed.js` executed an unconstrained `DELETE FROM sub_services`, completely wiping out all custom, admin-configured sub-services and active prices on every boot.
- **Remediation Status:** `RESOLVED & VERIFIED`. Converted to non-destructive insertion using `INSERT INTO sub_services ... WHERE NOT EXISTS (...)`. Added `catalog-seed.spec.ts` with 9 passing regression tests.

### `GAP-03` · Workflow Corruption: Booking Completion Cancel Dialog is Ineffective
- **Location:** `mobile/lib/features/provider/provider_active_job_cockpit_screen.dart:177`
- **Impact:** The code checks `if (shouldContinue != true && !mounted) return;`. Because `null != true` evaluates to `true` and `!mounted` is `false` while the widget remains mounted, the boolean `&&` evaluates to `false`. As a result, **cancelling or dismissing the dialog proceeds with service completion anyway**, bypassing the user's intent.
- **Remediation Status:** `OPEN`. Needs logic operator fix from `&&` to `||`.

---

## 3. P1 — High Severity Security, Integrity & Compliance Findings

### `GAP-04` · Route Shadowing: Admin Photo Moderation Endpoint is Unreachable
- **Location:** `backend/src/ratings/ratings-admin.controller.ts:22,42`
- **Impact:** Declares `@Patch(':id/moderation')` before `@Patch('photos/:photoId/moderation')`. In Express routing order, a call to `/admin/reviews/photos/<id>/moderation` binds `'photos'` to `:id`, routing to the review handler and returning `404 Review not found`.
- **Status:** `OPEN`. Literal segment must be declared before parameterized segment.

### `GAP-05` · Missing Access Control: Admin `/trust` Route Lacks Code-Level Role Checks
- **Location:** `admin/src/app/trust/page.tsx:37`
- **Impact:** The page invokes `getSession()` but performs zero role checks. The navigation sidebar hiding is a visual convenience, not a security boundary (pinned in Playwright test `admin-operations.spec.ts:148` as `test.fixme`). Any authenticated staff user (e.g., `support_agent`) can navigate directly to `/trust`.
- **Status:** `OPEN`. Needs code-level role enforcement.

### `GAP-06` · RBAC Role Mismatch: Navigation Grants `/support` to `auditor` but Backend Rejects
- **Location:** `admin/src/components/admin-shell.tsx:11`, `backend/src/common/authorization/permission-policies.ts:465-471`
- **Impact:** Admin nav displays the Complaints & Support link to `auditor`, but backend policies exclude `auditor` from `adminComplaintsRead`. Clicking the link results in immediate `403 Forbidden` and redirect to `/unauthorized`.
- **Status:** `OPEN`. Navigation list must align with backend authorization policies.

### `GAP-07` · Illegal State Transitions: Admin Guarantee Status Dropdown Permits Conflicts
- **Location:** `admin/src/app/guarantees/[id]/page.tsx:88-99`
- **Impact:** Renders all six guarantee statuses in a flat `<select>` without enforcing valid lifecycle transitions (unlike complaints). Operators can submit invalid transitions (e.g., `COMPLETED -> PENDING`), triggering a 409 Conflict that crashes the UI to `error.tsx`.
- **Status:** `OPEN`. Requires client-side transition table.

### `GAP-08` · Schema Hygeine: Orphan Migration Shadows Applied Migration
- **Location:** `backend/src/database/migrations/1789735751504-add-phone-to-users.ts`
- **Impact:** File exists outside both configured TypeORM globs (`backend/migrations/`). Its schema changes were separately applied by `1789748288429`. Promoting this orphan would cause migrations to crash with PostgreSQL error `42701 duplicate_column`.
- **Status:** `OPEN`. Dead file must be removed.

### `GAP-09` · Migration Timestamp Collision: Two Migrations Share Identical Timestamp
- **Location:** `1786521300000-BookingLineItems.ts` & `1786521300000-ComplaintsSchema.ts`
- **Impact:** Relative execution order depends on filesystem glob sorting.
- **Status:** `OPEN`. One timestamp should be re-keyed.

### `GAP-10` · Compliance Audit Trail Erasure: Foreign Key Cascade on User Deletion
- **Location:** `backend/migrations/1789749980000-RestoreBookingIntegrity.ts:93-94`
- **Impact:** `auth_audit_events.user_id` foreign key was restored as `ON DELETE CASCADE` (previously `SET NULL`). Deleting a user in PostgreSQL completely purges their authentication security audit trail.
- **Status:** `OPEN`. Foreign key action must be restored to `SET NULL`.

### `GAP-11` · Database Invariant Void: Complaint State Machine Unenforced at SQL Level
- **Location:** `shared/complaint-lifecycle.types.ts:27-57`, `backend/src/support/complaints/complaint.entity.ts`
- **Impact:** While `booking_events` enforces transitions via PostgreSQL triggers, `complaints` relies solely on application logic. Direct database updates bypass all lifecycle rules.
- **Status:** `OPEN`.

### `GAP-12` · Concurrency Hole: Chat Message `clientMessageId` Lacks Unique Constraint
- **Location:** `backend/src/bookings/domain/booking-message.entity.ts:30-36`
- **Impact:** Declares `client_message_id varchar(64)` as nullable without a unique index. Retried `POST /bookings/:id/messages` calls create duplicate chat rows.
- **Status:** `OPEN`. Requires unique constraint on `(booking_id, client_message_id)`.

### `GAP-13` · Unauthenticated Mock Stub: `inbox.controller.ts` Shipped in Backend Source
- **Location:** `backend/src/notifications/inbox.controller.ts:6`
- **Impact:** Contains `@Public() GET /api/v1/notifications/inbox` returning dummy hardcoded JSON. Unmounted in `AppModule`, but presents a security risk if inadvertently imported.
- **Status:** `OPEN`. Dead controller must be removed.

### `GAP-14` · Input Validation Bypass: Admin Complaint Status Update Uses Type Literal
- **Location:** `backend/src/admin/admin-management.controller.ts:52`
- **Impact:** Uses inline type literal `{ status: ComplaintStatus; resolutionNotes?: string }` instead of a class DTO. Bypasses NestJS `ValidationPipe({ whitelist: true })`, allowing arbitrary payload fields to reach services.
- **Status:** `OPEN`. Must be replaced with a decorated class DTO.

### `GAP-17` · UI Rendering Void: Admin `UserDetail` Type Mismatches API Response
- **Location:** `admin/src/features/operations/types.ts:16`, `backend/src/admin/admin-management.service.ts:150-156`
- **Impact:** Admin TypeScript interface expects `email` and `name`, but backend intentionally returns minimal PII (`{ id, status, roles, createdAt, updatedAt }`). As a result, submitter name and email render as blank strings on case dossiers (`support/[complaintId]/page.tsx:217`).
- **Status:** `OPEN`.

### `GAP-18` · Information Disclosure: `/admin/analytics` Accessible by Support Agents
- **Location:** `admin/src/app/page.tsx:23-25`, `backend/src/admin/admin-analytics.controller.ts:11`
- **Impact:** While the Next.js page checks for `operations_administrator`, the underlying backend endpoint requires only `adminBookingsRead`, which includes `support_agent` and `trust_safety_reviewer`. Direct API calls leak platform-wide financial volume to support staff.
- **Status:** `OPEN`.

### `GAP-19` / `GAP-40` · Fabricated Job Proof: Simulated Dummy PNGs Bypassing Photo Proof
- **Location:** `mobile/lib/design_system/fix_job_proof_dialog.dart:97-176, 391-406`
- **Impact:** "Simulate test photos" button exists in production code; camera capture failures silently substitute a 1x1 transparent PNG; stored in an in-memory singleton `JobProofRepository` that is never uploaded to the backend. Technicians can complete jobs without photographic evidence.
- **Status:** `OPEN`.

### `GAP-41` · Simulated Payment Success: Checkout Sheet Emits Fake Receipt
- **Location:** `mobile/lib/design_system/fix_payment_checkout_sheet.dart:146, 740, 789`
- **Impact:** If `onProcessPayment` callback is omitted, a 600ms delay triggers a fake "Payment Successful! / VERIFIED & PAID" celebration dialog.
- **Status:** `OPEN`.

### `GAP-42` · Statutory Tax Defect: Invoice PDF Carries Hardcoded GSTIN and Conflicting Addresses
- **Location:** `mobile/lib/features/payments/fix_pdf_invoice_builder.dart:13-19`, `invoice_screen.dart:283-299`
- **Impact:** PDF hardcodes placeholder GSTIN `24AAACF1234F1Z5` and an Ahmedabad company address, while the screen displays a Bengaluru company address with the same GSTIN. The verification QR code links to `https://fixnow.app/verify/invoice`, which returns a 404.
- **Status:** `OPEN`.

### `GAP-43` / `GAP-56` · Phantom UI Action: Notification "Clear All" Never Persists
- **Location:** `mobile/lib/features/notifications/notification_repository.dart:90-96`
- **Impact:** Maintained purely via a local in-memory `_deletedIds` set. No backend delete endpoint exists. All dismissed notifications reappear on app restart.
- **Status:** `OPEN`.

### `GAP-44` · Fabricated Staff Identity: Admin Shell Renders Hardcoded "Chief Dispatcher"
- **Location:** `admin/src/components/admin-shell.tsx:114-122`
- **Impact:** Every authenticated operator sees the hardcoded name "Chief Dispatcher" and a third-party Google avatar URL, because `AdminSession` carries no name or email field.
- **Status:** `OPEN`.

### `GAP-50` · Bloat & Confusion: 22 Mobile Files Completely Unreachable from `main.dart`
- **Location:** Listed in Section 6 below.
- **Status:** `OPEN`.

### `GAP-51` · Unwired Core Feature: Entire In-App Audio Calling Feature Unwired
- **Location:** `mobile/lib/features/call/call_repository.dart:12`, `call_session.dart:32`
- **Impact:** Backend and WebSockets support full calling lifecycle, and UI displays Call buttons, but `HttpCallRepository` is never instantiated.
- **Status:** `OPEN`.

---

## 4. P2 — Medium Severity Workflow, Query & Structural Findings

| ID | Module | Affected Files & Symbols | Description & Failure Mode |
|---|---|---|---|
| `GAP-15` | Database | `recurring_schedules`, `guarantee_claims`, `review_photo_moderation_events` | Critical tables lack foreign keys. `guarantee_claims.evidence_urls` uses `simple-array` (comma-delimited text), which corrupts URLs containing query commas. |
| `GAP-16` | Testing | `scripts/verify-schema.ts:232-235` | Schema behavior probes (orphan booking FK check, negative amount check, lat/lng bounds) silently skip on empty database. |
| `GAP-20` | Admin | `admin/src/app/bookings/page.tsx:26-28` | Emergency count in alert banner is calculated by substring matching `"emergency"` against description. |
| `GAP-21` | Admin | `admin/src/app/guarantees/[id]/page.tsx:31,39` | Server actions `throw new Error(...)` instead of returning standard failure results, triggering full-page `error.tsx`. |
| `GAP-22` | Mobile | `mobile/lib/features/location/url_launcher_stub.dart:1-3` | Native URL launcher stub is an empty function; shows "Opening directions" toast while doing nothing. |
| `GAP-23` | Admin | `admin/src/app/{support, trust, services, search, guarantees}/page.tsx` | Seven admin pages load unpaginated full table datasets into memory. `/search` performs 2-4 sequential awaits instead of parallel queries. |
| `GAP-24` | Mobile | `mobile/lib/features/provider/provider_jobs_screen.dart:391-494` | 7-day date filter strip toggles visual selection but never filters the job list (`currentJobs` calculated beforehand). |
| `GAP-25` | Admin | `admin/src/app/bookings/page.tsx:79` | `nextCursor` is read only to display "More records available" banner; no "Load More" button exists (list capped at 20). |
| `GAP-26` | Admin | `admin/src/components/admin-shell.tsx:19` | Nav active tab highlight fails for Provider KYC (`"Provider KYC Verification"` vs `"Providers & KYC Verification"`). |
| `GAP-27` | Admin | `admin/src/app/bookings/page.tsx:97` | Table rows are plain `<tr>` elements without navigation links into `/bookings/[bookingId]`. |
| `GAP-28` | Admin | `providers/page.tsx:119-124`, `support/page.tsx:132-137` | Permanent static placeholder panes ("RIGHT PANE: Placeholder Dossier") take up 40% of the screen. |
| `GAP-34` | Admin | `admin/src/auth/actions.ts` | Next.js server actions have no CSRF tokens beyond Origin checking; login server action has no rate limiter. |
| `GAP-35` | Database | `review-photo.entity.ts:24` | Entity defines column length `varchar(512)` while PostgreSQL column is `varchar(16)`. |
| `GAP-36` | Database | `ComplaintStatus`, `PushPlatform`, `GuaranteeClaimStatus` | TypeScript enums omit `enumName`, causing type-name drift against PostgreSQL native enums. |
| `GAP-45` | Mobile | `auth_screen.dart:785`, `verification_screen.dart:697`, `push_settings_card.dart:261` | Five mobile controls collect input but do nothing (Referral code, Biometric switch, Push toggles, Callback button, Payment methods row). |
| `GAP-46` | Mobile | `design_system/fix_banner.dart:43` | `showFixBanner` renders live no-op button when action label is provided without handler (`onPressed: onAction ?? () {}`). |
| `GAP-47` | Mobile | `notification_center_screen.dart:786-859` | Notification sheet displays a Close button only; no navigation path exists to open referenced invoices. |
| `GAP-48` | Mobile | `fix_payment_checkout_sheet.dart:592`, `cancellation_dialog.dart:77` | Hardcoded policy text contradicts actual business rules (fake ₹250 wallet balance, ₹99 dispatch fee vs 100% refund). |
| `GAP-52` | Mobile | `fix_service_card_gallery.dart`, `fix_provider_card_gallery.dart` | Two demo galleries containing fake ratings and providers compile into the production app. |
| `GAP-53` | Mobile | `mobile/lib/design_system/` | 33 unreferenced design-system widgets compiled into binary. |
| `GAP-54` | Admin | `admin/src/app/{analytics, users, users/[userId]}/page.tsx` | Completely orphaned pages with zero inbound links. |
| `GAP-57` | Admin | `admin/src/app/` | Backend endpoints for review and photo moderation exist, but admin dashboard provides zero UI to access them. |
| `GAP-58` | Admin | `admin/src/app/guarantees/[id]/page.tsx` | Missing client-side transition table for guarantee claims. |
| `GAP-71` | Shared | `shared/complaint-lifecycle.types.ts` vs `admin/src/features/operations/complaint-lifecycle.ts` | Complaint lifecycle transition rules defined twice across shared and admin code; prone to silent drift. |
| `GAP-72` | Admin | `admin/src/app/**` | Helper `shortId()` copy-pasted across 10 separate admin files. |
| `GAP-73` | Admin | `operations/api.ts` vs `users/api.ts` | Two conflicting `getUser` client implementations returning different types. |
| `GAP-74` | Admin | `auth/api.ts` vs `management-api.ts` | Two divergent admin fetch wrappers with conflicting error handling semantics. |
| `GAP-75` | Admin | `admin-shell.tsx` vs `search/page.tsx` | Staff role lists duplicated across 7 admin files with divergent permission grants. |
| `GAP-76` | Mobile | `sub_service_catalog_screen.dart` vs `service_discovery_screen.dart` | Two duplicate category rating renderers with divergent honesty rules. |
| `GAP-77` | Mobile | `fix_service_card.dart` vs `sub_service_catalog_screen.dart` | Duplicate `_formatCompactCount` and `_formatReviewCount` string formatting helpers. |
| `GAP-78` | Backend | `notifications/inbox.controller.ts` vs `notifications/domain/inbox.controller.ts` | Duplicate inbox controller files (one active, one dead stub). |
| `GAP-84` | Testing | Controllers | 11 backend controllers lack dedicated test specifications. |
| `GAP-85` | Testing | Services | Critical services (`admin-operations.service.ts`, `booking-dispatch.handlers.ts`, `resource-ownership.ts`) lack unit tests. |
| `GAP-86` | Testing | Shared | All 17 `shared/*.types.ts` contract files lack unit tests. |
| `GAP-87` | Testing | Admin | 12 of 18 admin routes lack automated test coverage. |
| `GAP-88` | Testing | E2E | Playwright end-to-end test suite unexecuted. |

---

## 5. P3 — Low Severity & Polish Findings

- `GAP-29`: Mobile address model fabricates default location (`Bengaluru`, `560034`).
- `GAP-30`: Booking tracking screen displays a hardcoded Google avatar for every user.
- `GAP-38`: Mobile tracking hardcodes public OpenStreetMap raster tiles without custom User-Agent.
- `GAP-39`: Dead native MethodChannels in Android `MainActivity.kt` (`audio_tone`, `voice_stream`).
- `GAP-49`: Permanently disabled "Corporate SSO" button on admin login page.
- `GAP-55`: Admin `/unauthorized` page performs no session check.
- `GAP-67`: Admin `/bookings` reads `nextCursor` but provides no "Load More" action.
- `GAP-68`: Provider jobs 7-day strip is purely cosmetic.
- `GAP-69`: Mobile auth state machine lacks dedicated screens for `offline` and `failure` states.
- `GAP-70`: Custom brand fonts (Playfair Display, Inter) commented out in `pubspec.yaml` due to missing TTF assets.
- `GAP-79`: Status badge label mappings duplicated across 4 admin files.
- `GAP-80`: Company legal address strings disagree between PDF (Ahmedabad) and UI (Bengaluru).
- `GAP-89`: Test scripts (`fix_tests.dart`) modify test source files; mock transports shipped in production code.

---

## 6. Dead Code & Unreachable Screens Roster

### 6.1 Unreachable Flutter Screens (6 Files)
1. `features/ai/ai_diagnostic_screen.dart` (Replaced by `problem_diagnosis_screen.dart`)
2. `features/ai/ai_recommendation_screen.dart`
3. `features/support/complaint_detail_screen.dart` (Used only in test fixtures; replaced by `complaint_list_screen.dart`)
4. `features/provider/provider_setup_screen.dart`
5. `auth/provider_onboarding_entry_screen.dart`
6. `features/tracking/booking_tracking_overview_screen.dart`

### 6.2 Dead Backend Controllers & Modules (1 File)
1. `backend/src/notifications/inbox.controller.ts` (Dead `@Public()` stub omitted from all modules).

### 6.3 Orphaned Admin Web Routes (3 Routes)
1. `/analytics` (Zero navigation links; duplicate of dashboard analytics).
2. `/users` (Zero navigation links; user management table completely inaccessible).
3. `/users/[userId]` (Reachable only from orphaned `/users` or deep guarantee links).

---

## 7. Inventory of Shipped Stubs, Mocks & Fabricated Data

| Feature Area | Component / Source Location | Fabricated Element / Stubbed Behavior |
|---|---|---|
| **Job Proof Photos** | `fix_job_proof_dialog.dart:391` | "Simulate test photos" button inserts 1x1 dummy PNG as valid proof; saved in in-memory singleton. |
| **Payment Checkout** | `fix_payment_checkout_sheet.dart:146` | Shows "Payment Successful! VERIFIED & PAID" after 600ms fake delay if callback omitted. |
| **Tax Invoicing** | `fix_pdf_invoice_builder.dart:13` | Hardcoded fake GSTIN `24AAACF1234F1Z5` and non-existent QR verification URL. |
| **Staff Identity** | `admin-shell.tsx:114` | Displays hardcoded "Chief Dispatcher" and external avatar on all admin pages. |
| **Wallet Balance** | `fix_payment_checkout_sheet.dart:592` | Hardcodes `'Balance: ₹250 available'` despite having no customer wallet backend. |
| **Biometric Auth** | `verification_screen.dart:697` | UI switch for biometric login that toggles an inert local boolean. |
| **Demo Galleries** | `fix_service_card_gallery.dart` | Fake providers and 4.9 ratings compiled directly into the binary. |
