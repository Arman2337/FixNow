# FixNow — Test Coverage, Verification & Quality Assurance Inventory

**Audit Date:** 2026-10-13  
**Audit Scope:** Unit, Integration, Widget, Contract, E2E Suites, CI Pipelines, and Verification Scripts  
**Repository Surfaces:** `backend/`, `mobile/`, `admin/`, `shared/`, `e2e/`, `scripts/`, `.github/workflows/`  

---

## 1. Test Execution Baseline & Observed Results

| Test Suite / Tool | Framework / Runner | Target Surface | Test Specs / Files | Tests Executed | Observed Result | Notes & Limitations |
|---|---|---|---|---|---|---|
| **Backend Unit Tests** | Jest 29.x | `backend/src/` | 110 Test Suites | **953 Tests** | **PASSED (100%)** | Fully executed in this audit. Includes 9 new regression tests in `catalog-seed.spec.ts`. Mocks `DataSource` & external APIs. |
| **Backend Integration Tests** | Jest 29.x + Testcontainers | `backend/test/` | 14 Test Specs | 85 Tests | **UNEXECUTED** | Requires isolated PostgreSQL instance on port `55432`. Container environment was not active during audit (`GAP-81`). |
| **Mobile Widget & Acceptance** | Flutter Test / Dart 3.x | `mobile/test/` | 46 Test Files | **428 Tests** | **PASSED (100%)** | Exercises customer & provider UI flows, navigation shells, dialogs, and design system components. |
| **Admin Web Tests** | Vitest 1.x / React Testing Lib | `admin/src/` | 6 Test Specs | **35 Tests** | **PASSED (100%)** | Verifies Server Action authorization, complaint lifecycle helpers, and API response parsing. |
| **Playwright E2E Tests** | Playwright 1.x | `e2e/tests/` | 2 Test Specs | 13 Tests | **UNEXECUTED** | 12 active tests, 1 `test.fixme` (`admin-operations.spec.ts:148`). Blocked by missing headless browser binaries (`GAP-88`). |
| **Secret Scanner CI Gate** | Custom Node.js Regex Engine | Repository-wide | `scripts/scan-secrets.mjs`| 1,721 Blobs | **PASSED (0 findings)** | Executed `--self-test` (11/11 rules passed). Scan of 1,721 git blobs completed clean with 0 findings. |
| **Local Schema Verification** | Custom PG Inspector | Local PostgreSQL | `scripts/verify-schema.ts` | 54 Checks | **PASSED (54/54)** | Verified 45 entities, 39 migrations, 116 indexes, 47 foreign keys, 23 check constraints against local DB. |
| **Fresh DB Schema Gate** | Scratch DB Re-creator | Scratch DB | `scripts/verify-fresh-schema.ts`| 61 Checks | **PASSED (61/61)** | Executed against dedicated scratch database `fixnow_schema_gate`. Passed behavioral write probes. |

---

## 2. Backend Test Coverage & Spec Mapping

### 2.1 Fully Verified Backend Modules (Unit Test Evidenced)

| Module | Test Spec File | Test Count | Key Invariants Verified |
|---|---|---|---|
| **Identity & Authentication** | `auth/auth.service.spec.ts`, `auth/token-lifecycle.controller.spec.ts` | 48 | Argon2id hashing, 5-attempt lockout, 60s OTP cooldown, single-flight refresh de-dupe, token family revocation on replay. |
| **Catalog & Seeding** | `services/service-categories.service.spec.ts`, `services/catalog-seed.spec.ts` | 30 | Active category filtering, slug lookups, non-destructive `WHERE NOT EXISTS` idempotent seed safety. |
| **Booking Lifecycle** | `bookings/bookings.service.spec.ts`, `bookings/bookings.controller.spec.ts` | 52 | Optimistic locking CAS, HMAC 4-digit service-start OTP generation, GST minor amount math, keyset pagination. |
| **Matching & Dispatch** | `matching/matching.service.spec.ts` | 16 | Haversine distance calculations, skill matching, provider capacity boundaries under pessimistic write lock. |
| **Payments & Escrow** | `payments/payments.service.spec.ts`, `payments/payment-gateway.spec.ts` | 41 | Razorpay HMAC-SHA256 signature verification over raw body buffer, duplicate webhook rejection, mandatory refund idempotency keys. |
| **Chat & Messaging** | `bookings/booking-messages.controller.spec.ts`, `bookings/booking-messages.service.spec.ts` | 15 | Message size bounds (1-2000 chars), participant ownership checks, delivery timestamp ordering. |
| **Support & Complaints** | `support/complaints/complaints.controller.spec.ts`, `support/complaints/complaints.service.spec.ts` | 22 | Multi-stage lifecycle transitions, immutable audit log generation, callback requests. |
| **Customer Addresses** | `users/customer-addresses.controller.spec.ts` | 12 | Geocoding bounds validation (`@IsLatitude`, `@IsLongitude`), default address exclusive toggling. |
| **Provider Skills & Availability** | `providers/provider-skills.service.spec.ts`, `providers/provider-availability.service.spec.ts` | 28 | Weekly schedule JSON validation, date exception caps (<=90), reviewer-only skill verification. |
| **Emergency SOS** | `emergency/emergency.service.spec.ts` | 14 | Max 1 open emergency request per user, wave radius expansion progression (3km -> 6km -> 12km). |
| **Realtime Signaling** | `realtime/realtime.gateway.spec.ts`, `realtime/realtime-session-revalidation.spec.ts` | 18 | 5-second handshake auth timer, 3-connection per principal limit, heartbeat liveness, topic subscription access control. |
| **Health & Observability** | `health/health.controller.spec.ts`, `observability/metrics.controller.spec.ts` | 16 | Zero-DB liveness probe, 3-second readiness DB ping timeout, Prometheus OpenMetrics format export. |

---

## 3. Untested Backend Surface & Verification Gaps (`GAP-81` to `GAP-86`)

Despite strong unit test coverage across core services, several foundational architectural layers lack dedicated test specifications:

### 3.1 Untested Controllers (11 Controllers)
The following controllers have **zero dedicated `.controller.spec.ts` files**:
1. `payments/payments.controller.ts` (Tested indirectly via service spec; controller route decorators unverified)
2. `payments/payments-admin.controller.ts`
3. `payments/provider-earnings.controller.ts`
4. `providers/provider-application.controller.ts`
5. `providers/provider-profile.controller.ts`
6. `providers/availability/provider-availability.controller.ts`
7. `providers/documents/provider-document.controller.ts`
8. `providers/verification/provider-verification.controller.ts`
9. `ratings/ratings.controller.ts`
10. `ratings/ratings-admin.controller.ts`
11. `emergency/emergency.controller.ts`

### 3.2 Critical Untested Infrastructure Services
1. **Transactional Outbox Engine (`outbox/outbox.service.ts`):** 14,257 bytes of critical infrastructure code with **zero tests**. The lease locking, deduplication, retry exponential backoff, and poison message handling are completely unverified by unit tests (`GAP-82`).
2. **Storage & Malware Scanner (`storage/**`):** `clamav-malware-scanner.ts` and `s3-private-object-storage.ts` have **zero tests**. KYC document security rests on this unverified code (`GAP-83`).
3. **Dispatch Expiry Sweeper (`bookings/booking-dispatch.handlers.ts`):** 9,156 bytes of outbox-driven dispatch handlers with no test coverage (`GAP-85`).
4. **Shared Type Contracts (`shared/*.types.ts`):** All 17 shared contract files lack unit tests, leaving lifecycle state machine tables vulnerable to unverified edits (`GAP-86`).

---

## 4. Mobile Test Coverage Inventory (Flutter)

### 4.1 Passing Mobile Test Suites (428 Tests)
- `offline_first_discovery_test.dart`: Verifies category caching, offline banners, and starting price displays.
- `customer_discovery_test.dart`: Tests quick search, filter chips, and category carousels.
- `sub_service_catalog_screen_test.dart`: Tests sub-service cart steppers, quantity increments, floating cart sheet.
- `service_request_acceptance_test.dart`: Validates date picker, slot selection, and booking request submission.
- `booking_tracking_test.dart`: Validates connection status card, 4-digit security OTP display, and live map rendering.
- `chat_screen_test.dart`: Validates message list rendering, composer text input, and realtime stream updates.
- `invoice_screen_test.dart` & `pdf_tax_invoice_test.dart`: Validates invoice breakdown, GST math, and PDF generation.
- `problem_diagnosis_screen_test.dart`: Tests multimodal photo and voice note diagnostic submission.
- `emergency_screen_test.dart`: Verifies 3-second hold-to-confirm SOS button behavior.
- `welcome_screen_test.dart`: Tests onboarding role selection and small-screen responsiveness (<360dp width).

### 4.2 Untested & Problematic Mobile Areas
- **Calling Subsystem:** `features/call/` contains unit tests for mock call sessions, but the actual repository is unwired in production code (`GAP-51`).
- **Simulated Test Harnesses:** `mobile/lib/features/location/saved_address.dart` ships an internal `MockApiTransport` inside production code (`GAP-89`).
- **Unexecuted Device Scenarios:** Native Android `MainActivity.kt` MethodChannels (`audio_tone`, `voice_stream`) have zero tests (`GAP-39`).

---

## 5. Admin Web Test Coverage Inventory (Next.js / Vitest)

### 5.1 Passing Admin Vitest Specs (35 Tests)
- `admin/src/auth/actions.test.ts`: Tests admin login form handling, credential validation, and cookie assignment.
- `admin/src/features/operations/complaint-lifecycle.test.ts`: Verifies complaint status transition validation logic.
- `admin/src/features/management-api.test.ts`: Tests HTTP error mapping (401 -> login redirect, 403 -> unauthorized).
- `admin/src/features/search/search.test.ts`: Tests multi-entity search query parsing and result filtering.

### 5.2 Admin Testing Gaps (`GAP-87`)
12 of the 18 admin routes have **zero automated tests**:
- `/` (Operations Overview Dashboard)
- `/analytics` (Orphaned Analytics Page)
- `/bookings` (Dispatch Queue)
- `/bookings/[bookingId]` (Booking Dossier & Intervention)
- `/guarantees` (Warranty Claims Queue)
- `/guarantees/[id]` (Claim Dossier & Re-Service Trigger)
- `/login` (Full Page Rendering)
- `/search` (Cross-Entity Search Results Page)
- `/services` (Service Category CRUD Forms)
- `/unauthorized` (403 Handler Page)
- `/users` (Orphaned User Management Table)
- `/users/[userId]` (User Detail Dossier)

---

## 6. End-to-End & Integration Test Limitations

### 6.1 Integration Suite Blocked (`GAP-81`)
- **Suite Command:** `npm run test:integration` (14 specs, 85 tests).
- **Blocker:** Tests configure `DataSource` targeting PostgreSQL on port `55432` (`test/support/test-data-source.ts:66-111`). Because no secondary PostgreSQL daemon was bound to that port, running the integration suite would result in connection timeouts.
- **Significance:** Unit tests mock database interactions and cannot prove referential integrity, transaction rollbacks, or lock contention.

### 6.2 Playwright E2E Suite Blocked (`GAP-88`)
- **Suite Command:** `npx playwright test` (2 specs, 13 tests).
- **Blocker:** Playwright browser binaries are not installed in the workspace container.
- **Key Finding:** Test `e2e/tests/admin-operations.spec.ts:148` is committed as `test.fixme`, explicitly documenting `GAP-05` (lack of role check on `/trust`).

---

## 7. Continuous Integration & Quality Gates Summary

FixNow defines 6 automated quality gates in `.github/workflows/ci.yml`:
1. **Lint & Static Correctness:** `eslint`, `flutter analyze`, `tsc --noEmit` -> Configured.
2. **Secrets Scanning:** `node scripts/scan-secrets.mjs` -> **PASSED** (0 findings on 1,721 blobs).
3. **Database Schema Gates:** `npm run schema:verify` -> **PASSED** (54/54 on local DB, 61/61 fresh).
4. **Backend Test Suite:** `npm run test:unit` -> **PASSED** (953/953 tests).
5. **Mobile Test Suite:** `flutter test` -> **PASSED** (428/428 tests).
6. **Admin Test Suite:** `npm test` -> **PASSED** (35/35 tests).
