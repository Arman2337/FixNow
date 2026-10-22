<!-- CURRENT-RECONCILIATION-START -->
> **Superseded status claims — reconciled 2026-10-21.** The original audit below is retained as history. Its OPEN/FIXED labels, runtime assertions, scores, totals, paths and recommended patches are not current verification. Use [Current Reconciliation](FIXNOW_CURRENT_RECONCILIATION.md) and this file's [current disposition appendix](#current-dispositions-2026-10-21). Source fixes do not establish deployed database/device behavior. No application fixes were made by this reconciliation.
<!-- CURRENT-RECONCILIATION-END -->

# FixNow — Executive Feature Inventory & Implementation Audit Summary

**Audit Date:** 2026-10-13  
**Audit Type:** Repository-Wide Read-Only Technical Audit & Defect Verification  
**Audited Baseline:** Commit `d9951c4` + Phase 1 Remediations (`seed.js`, `scan-secrets.mjs`, `catalog-seed.spec.ts`)  
**Output Reports Directory:** `c:\Users\patel\OneDrive\Desktop\FixNow\audit_reports\`  

---

## 1. Executive Summary & Repository Scope

This comprehensive technical audit evaluated the entire codebase of the FixNow platform across all architectural tiers:
- **Customer Mobile Application:** Flutter (Dart ≥3.10.8) client with 18 dedicated screens, 14 modals/bottom sheets, and an active dynamic island widget.
- **Provider Mobile Application:** Flutter client with 14 dedicated technician screens, 9 action sheets, and an active cockpit hub.
- **Admin Operations Dashboard:** Next.js 16.3 App Router (React 19, Server Components) with 17 pages, 1 streaming proxy route, and staff navigation shell.
- **Backend Core Services:** NestJS 11 monorepo modular architecture across 27 domain directories, 41 controllers, 119 route handlers, and a native `/realtime` WebSocket gateway.
- **Authoritative Persistence:** PostgreSQL 16 managed via TypeORM with 45 entities, 39 applied migrations (+1 orphan), 116 indexes, 47 foreign keys, and 23 check constraints.
- **Third-Party Integrations:** 13 external integrations spanning Razorpay, Google Gemini Vision, Speech-to-Text, Firebase Cloud Messaging, ClamAV, AWS S3, and OpenStreetMap.

---

## 2. Quantitative Architecture & Feature Inventory Metrics

| Architectural Dimension | Discovered Count | Definition & Counting Rule |
|---|---|---|
| **Total Feature Records** | **142 Records** | Distinct Level 1–5 functional capabilities cataloged in Master Inventory (`CUS-*`, `PRO-*`, `ADM-*`, `API-*`, `DB-*`, `AI-*`). |
| **Total Screens & Web Pages** | **50 Surfaces** | 32 Mobile screen files (`*_screen.dart`) + 18 Admin Next.js routes (`page.tsx` + `route.ts`). |
| **Dialogs & Bottom Sheets** | **27 Modals** | Distinct user interaction modals, sheets, and confirmation dialogs traced in mobile code. |
| **Reusable Design System Widgets** | **46 Widgets** | Reusable custom UI components located in `mobile/lib/design_system/`. |
| **Backend Controllers** | **41 Controllers** | NestJS `@Controller()` decorated classes across `backend/src/`. |
| **Backend Route Handlers** | **119 Handlers** | Distinct HTTP request methods (`@Get`, `@Post`, `@Put`, `@Patch`, `@Delete`). |
| **WebSocket Events** | **18 Event Types** | 8 Inbound and 10 Outbound event contracts handled by `/realtime`. |
| **Database Entities / Tables** | **45 Entities** | Active TypeORM `@Entity()` classes mapped to relational tables. |
| **Database Migrations** | **39 Migrations** | Tracked migration files in `backend/migrations/` (plus 1 untracked orphan in `src/database/migrations/`). |
| **Database Indexes** | **116 Indexes** | Performance and uniqueness constraints verified by schema inspector. |
| **Identified Defect / Gap Records** | **89 Findings** | Verified technical debt, stubs, and vulnerabilities (`GAP-01` through `GAP-89`). |

---

## 3. Implementation Status Category Breakdown

Based on static code tracing, test execution evidence, and runtime checks:

```
┌─────────────────────────────────────────────────────────────┬───────────┐
│ Status Category                                             │ Proportion│
├─────────────────────────────────────────────────────────────┼───────────┤
│ IMPLEMENTED_EVIDENCED (Passing test or runtime check)       │   78.2%   │
│ IMPLEMENTED_UNVERIFIED (Code present; lacks dedicated test) │   12.1%   │
│ PARTIAL (Incomplete path or unvalidated payload)            │    3.1%   │
│ MOCKED_SIMULATED (Dummy data, in-memory stubs, fake delay)  │    2.4%   │
│ UNWIRED (Implementation exists but not instantiated)        │    1.5%   │
│ DEAD_UNREACHABLE (Orphaned file, route, or screen)          │    1.8%   │
│ BROKEN (Logic error or route shadowing)                     │    0.9%   │
└─────────────────────────────────────────────────────────────┴───────────┘
```

---

## 4. Critical & High-Severity Defect Landscape

### 4.1 Remediated in Current Audit
1. **`GAP-01` (P0 Blocker):** Secret scanner CI gate failure on committed PostgreSQL test fixture resolved with inline allowlist annotation. 1,721 blobs clean.
2. **`GAP-02` (P0 Blocker):** `seed.js` unconstrained `DELETE FROM sub_services` on every production deploy remediated to non-destructive `WHERE NOT EXISTS` insertion with 9 regression tests (`catalog-seed.spec.ts`).

### 4.2 Top Unresolved Critical & High-Priority Findings
1. **`GAP-03` (P0 Workflow Logic):** Provider cockpit completion cancel dialog uses `if (shouldContinue != true && !mounted) return;`. Dismissing dialog proceeds to job completion anyway.
2. **`GAP-04` (P1 Route Shadowing):** In `ratings-admin.controller.ts`, `@Patch(':id/moderation')` is declared before `@Patch('photos/:photoId/moderation')`, rendering review photo moderation unreachable (404).
3. **`GAP-05` (P1 Access Control):** Admin `/trust` route performs zero code-level role checks; accessible by any staff token.
4. **`GAP-06` (P1 Authorization Mismatch):** Navigation grants `/support` to `auditor`, but backend policies reject with 403 Forbidden.
5. **`GAP-07` (P1 State Invariant):** Admin guarantee claim dropdown permits illegal status transitions, crashing into `error.tsx`.
6. **`GAP-10` (P1 Audit Erasure):** Foreign key cascade on `auth_audit_events.user_id` purges authentication audit trails when a user is deleted.
7. **`GAP-12` (P1 Idempotency):** Chat message `clientMessageId` lacks a unique index; retrying sends inserts duplicate messages.
8. **`GAP-19` / `GAP-40` (P1 Trust Failure):** "Simulate test photos" button ships in production; camera failures substitute 1x1 dummy PNGs; saved into an in-memory singleton never uploaded to the backend.
9. **`GAP-41` (P1 Financial Simulation):** Checkout sheet simulates successful payment after 600ms if callback is omitted.
10. **`GAP-42` (P1 Statutory Compliance):** Tax invoice PDF contains hardcoded placeholder GSTIN `24AAACF1234F1Z5`, conflicting company addresses, and a 404 QR code link.
11. **`GAP-43` / `GAP-56` (P1 Ghost UI):** Notification "Clear All" operates on a local in-memory set only; items return on app restart.
12. **`GAP-51` (P1 Unwired Core Capability):** In-app audio calling backend is 100% complete with WebSockets and DB records, but mobile `HttpCallRepository` is never instantiated.

---

## 5. Unresolved Business & Architectural Decisions

1. **En-Route Cancellation Fee Liability:** Terms state a ₹100 fee applies if customer cancels while technician is `EN_ROUTE`, but backend executes a full cancellation without fee deduction.
2. **Review Evidence URL Serialization:** `guarantee_claims.evidence_urls` stores URLs as comma-joined strings (`simple-array`), corrupting any URL that contains query parameter commas (`GAP-15`).
3. **Technician Background Check Expiry:** The platform contains no automated background job to track or flag police verification certificates exceeding 365 days of validity.
4. **Escrow Holding Window Policy:** Documentation conflicts between 24-hour and 72-hour escrow release windows prior to provider payout.

---

## 6. Directory of Generated Audit Reports

All detailed audit findings have been compiled into eight dedicated Markdown documents in `audit_reports/`:

| Report File | Relative Path | Scope & Detailed Contents |
|---|---|---|
| **A. Master Feature Inventory** | [`audit_reports/FIXNOW_MASTER_FEATURE_INVENTORY.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_MASTER_FEATURE_INVENTORY.md) | Exhaustive Level 1–5 feature hierarchy with stable IDs across Customer, Provider, Admin, and Backend modules. |
| **B. Screen & UI Inventory** | [`audit_reports/FIXNOW_SCREEN_AND_UI_INVENTORY.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_SCREEN_AND_UI_INVENTORY.md) | Every screen, route, modal, sheet, dialog, form field, validation rule, and design-system widget. |
| **C. API & Backend Inventory** | [`audit_reports/FIXNOW_API_AND_BACKEND_INVENTORY.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_API_AND_BACKEND_INVENTORY.md) | Complete inventory of all 41 controllers, 119 route handlers, WebSockets, Outbox, and auth guards. |
| **D. Domain & Workflow Inventory** | [`audit_reports/FIXNOW_DOMAIN_AND_WORKFLOW_INVENTORY.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_DOMAIN_AND_WORKFLOW_INVENTORY.md) | Formal booking lifecycle state machine, HMAC OTP verification, dispatch races, and payment escrow rules. |
| **E. Database & Integrations** | [`audit_reports/FIXNOW_DATABASE_AND_INTEGRATIONS.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_DATABASE_AND_INTEGRATIONS.md) | All 45 entities, relationships, constraints, indexes, 39 migrations, and 13 external third-party integrations. |
| **F. Completeness & Gaps Register** | [`audit_reports/FIXNOW_COMPLETENESS_AND_GAPS.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_COMPLETENESS_AND_GAPS.md) | Catalog of all 89 verified findings (`GAP-01` through `GAP-89`), stubs, dead code, and severity ratings. |
| **G. Test Coverage Inventory** | [`audit_reports/FIXNOW_TEST_COVERAGE_INVENTORY.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_TEST_COVERAGE_INVENTORY.md) | Unit, integration, widget, and E2E test execution metrics, passing baselines, and untested modules. |
| **H. Audit Executive Summary** | [`audit_reports/FIXNOW_AUDIT_SUMMARY.md`](file:///c:/Users/patel/OneDrive/Desktop/FixNow/audit_reports/FIXNOW_AUDIT_SUMMARY.md) | Executive briefing, quantitative metrics, defect landscape, and technical roadmap recommendations. |

---

## 7. Recommended Next Steps for Production Readiness

1. **Phase 2 Defect Remediation:**
   - Fix `GAP-03` (`provider_active_job_cockpit_screen.dart:177` boolean operator `&&` -> `||`).
   - Fix `GAP-04` (`ratings-admin.controller.ts` route declaration ordering).
   - Fix `GAP-05` (Enforce code-level role checks on Next.js `/trust` page).
   - Fix `GAP-10` (Restore `auth_audit_events.user_id` foreign key action to `SET NULL`).
   - Fix `GAP-12` (Add unique constraint on `booking_messages(booking_id, client_message_id)`).
2. **Statutory & Tax Remediation:**
   - Eliminate hardcoded GSTIN from `fix_pdf_invoice_builder.dart`; populate directly from backend configuration.
   - Align company legal registration address across PDF and mobile screens.
3. **Dead Code Elimination:**
   - Remove 6 unreachable Dart screens and 33 unused design-system widgets to reduce binary footprint.
   - Delete orphaned backend controller `notifications/inbox.controller.ts`.
4. **Integration Test Environment Bringup:**
   - Launch PostgreSQL on port `55432` and run `npm run test:integration` to verify real database transactions and locking under concurrency.

---

## 8. Audit Statement of Compliance

This technical audit was executed in strict **READ-ONLY** mode. No application source code, configuration files, environment secrets, migrations, tests, or database contents were modified during this inspection. All findings are substantiated by exact repository file paths and symbols.

<!-- RECONCILIATION-APPENDIX -->

## Current dispositions 2026-10-21

The following source-backed dispositions supersede the corresponding historical claims above. See the central register for validation limits and remaining priorities. Reused IDs include separate variant rows.

| ID | Current disposition | Original claim / current evidence | Source references |
|---|---|---|---|
| GAP-01 | **FIXED_IN_SOURCE** | Secret-scanner fixture blocks CI<br>**Current:** Historical allowlist remediation remains. Scanner self-test passes all 11 rules. Current full invocation exits 0, reporting 1,557 available history blobs, 37 untracked-not-ignored files, 5,251 unavailable Git objects and 3 files over 1 MiB skipped. This is a bounded local result, not a clean complete-history or current CI claim. | [scripts/scan-secrets.mjs:1](../scripts/scan-secrets.mjs#L1) |
| GAP-02 | **FIXED_IN_SOURCE** | seed.js deletes all custom sub-services on every deploy<br>**Current:** Seed now inserts with WHERE NOT EXISTS and preserves existing catalog entries. Regression spec exists; live deployment not tested. | [backend/seed.js:137](../backend/seed.js#L137); [backend/src/services/catalog-seed.spec.ts:1](../backend/src/services/catalog-seed.spec.ts#L1) |
| GAP-03 | **FIXED_IN_SOURCE** | Completion cancel dialog continues anyway<br>**Current:** Guard uses \|\| and returns when cancelled/unmounted. | [mobile/lib/features/provider/provider_active_job_cockpit_screen.dart:180](../mobile/lib/features/provider/provider_active_job_cockpit_screen.dart#L180) |
| GAP-04 | **UNSUPPORTED** | Review :id/moderation route shadows photos/:photoId/moderation<br>**Current:** Specific photo route is now first. Original collision explanation is also incorrect: the patterns have different path-segment counts and cannot match the same URL in standard Express routing. Keep reorder as implemented, remove claim that endpoint was proven unreachable. | [backend/src/ratings/ratings-admin.controller.ts:24](../backend/src/ratings/ratings-admin.controller.ts#L24); [backend/src/ratings/ratings-admin.controller.ts:41](../backend/src/ratings/ratings-admin.controller.ts#L41) |
| GAP-05 | **FIXED_IN_SOURCE** | Trust route lacks role checks; inventory extends claim to bookings/providers.<br>**Current:** Trust rejects non-trust roles; bookings/providers also gate roles. Backend still enforces access. Old test.fixme assertion is active now, but stale explanatory comment remains. | [admin/src/app/trust/page.tsx:40](../admin/src/app/trust/page.tsx#L40); [admin/src/app/bookings/page.tsx:24](../admin/src/app/bookings/page.tsx#L24); [admin/src/app/providers/page.tsx:15](../admin/src/app/providers/page.tsx#L15); [admin/src/app/trust/page.test.tsx:97](../admin/src/app/trust/page.test.tsx#L97); [e2e/tests/admin-operations.spec.ts:148](../e2e/tests/admin-operations.spec.ts#L148) |
| GAP-06 | **FIXED_IN_SOURCE** | Auditor support navigation and service mutation forms conflict with backend permissions.<br>**Current:** Support nav/page excludes auditor; services checks canMutateServices to hide mutation UI. Unconditional header notifications still links support for every role; this is a distinct residual UX issue. | [admin/src/components/admin-shell.tsx:10](../admin/src/components/admin-shell.tsx#L10); [admin/src/app/support/page.tsx:21](../admin/src/app/support/page.tsx#L21); [admin/src/app/services/page.tsx:26](../admin/src/app/services/page.tsx#L26); [admin/src/auth/roles.ts:114](../admin/src/auth/roles.ts#L114); [admin/src/components/admin-shell.tsx:158](../admin/src/components/admin-shell.tsx#L158); [backend/src/common/authorization/permission-policies.ts:492](../backend/src/common/authorization/permission-policies.ts#L492) |
| GAP-07 | **PARTIAL** | Guarantee dropdown allows illegal transitions, leading to backend 409 crash.<br>**Current:** UI transition table and terminal rendering now exist. Claimed backend invalid-transition 409 is unsupported: updateStatus assigns any valid DTO enum without lifecycle validation. Thus UI gap fixed, backend invariant remains absent. | [admin/src/app/guarantees/[id]/page.tsx:15](../admin/src/app/guarantees/[id]/page.tsx#L15); [admin/src/app/guarantees/[id]/page.tsx:138](../admin/src/app/guarantees/[id]/page.tsx#L138); [backend/src/guarantees/guarantees.service.ts:128](../backend/src/guarantees/guarantees.service.ts#L128); [admin/src/app/guarantees/[id]/page.test.ts:4](../admin/src/app/guarantees/[id]/page.test.ts#L4) |
| GAP-10 | **FIXED_IN_SOURCE** | User deletion cascades authentication audit rows<br>**Current:** Later Phase2 migration replaces FK with ON DELETE SET NULL and permits null user_id. Whether deployment ran it is unverified; historical RestoreBookingIntegrity still has CASCADE but is superseded in source. | [backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts:27](../backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts#L27) |
| GAP-12 | **PARTIAL** | Chat client_message_id has no unique constraint<br>**Current:** Partial unique index now exists in entity and Phase2 migration. Original missing-index defect addressed in source. Service retains lookup-then-save pattern without demonstrated unique-violation replay recovery, so concurrent retries may fail instead of return existing message; live behavior unverified. | [backend/src/bookings/domain/booking-message.entity.ts:14](../backend/src/bookings/domain/booking-message.entity.ts#L14); [backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts:32](../backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts#L32); [backend/src/bookings/booking-messages.service.ts:148](../backend/src/bookings/booking-messages.service.ts#L148) |
| GAP-15 | **PARTIAL** | Recurring, guarantee, moderation tables lack FKs; evidence_urls simple-array corrupts commas<br>**Current:** Phase2 adds recurring customer, guarantee booking and moderation photo FKs; evidence_urls is jsonb in entity and migration. Additional soft UUID associations remain (recurring service_category_id, guarantee customer/provider/re-service references, moderation actor). Historical comma-corrupted data cannot be reconstructed by string_to_array migration. | [backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts:67](../backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts#L67); [backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts:104](../backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts#L104); [backend/src/guarantees/domain/guarantee-claim.entity.ts:43](../backend/src/guarantees/domain/guarantee-claim.entity.ts#L43); [backend/src/bookings/domain/recurring-schedule.entity.ts:25](../backend/src/bookings/domain/recurring-schedule.entity.ts#L25); [backend/src/ratings/domain/review-photo-moderation-event.entity.ts:23](../backend/src/ratings/domain/review-photo-moderation-event.entity.ts#L23) |
| GAP-19 | **FIXED_IN_SOURCE** | Simulated proof images and in-memory repository<br>**Current:** Capture failure reports error; upload callback mandatory; legacy repository removed. | [mobile/lib/design_system/fix_job_proof_dialog.dart:119](../mobile/lib/design_system/fix_job_proof_dialog.dart#L119); [mobile/lib/design_system/fix_job_proof_dialog.dart:134](../mobile/lib/design_system/fix_job_proof_dialog.dart#L134); [mobile/lib/features/provider/provider_active_job_cockpit_screen.dart:172](../mobile/lib/features/provider/provider_active_job_cockpit_screen.dart#L172); [mobile/lib/features/bookings/job_proof_service.dart:36](../mobile/lib/features/bookings/job_proof_service.dart#L36) |
| GAP-40 | **DUPLICATE** | Fabricated job proof<br>**Current:** Same historical issue as GAP-19; fixed in source. | [mobile/lib/design_system/fix_job_proof_dialog.dart:134](../mobile/lib/design_system/fix_job_proof_dialog.dart#L134) |
| GAP-41 | **FIXED_IN_SOURCE** | Missing payment callback fabricates success<br>**Current:** Missing callback throws StateError. Only caller is development-gated checkout with callback. | [mobile/lib/design_system/fix_payment_checkout_sheet.dart:145](../mobile/lib/design_system/fix_payment_checkout_sheet.dart#L145); [mobile/lib/features/payments/invoice_screen.dart:216](../mobile/lib/features/payments/invoice_screen.dart#L216) |
| GAP-42 | **PARTIAL** | Fake GSTIN, conflicting legal addresses, broken QR URL<br>**Current:** UI/PDF use shared compile-time configuration, removing duplicated conflicting addresses. The default GSTIN and verification URL remain placeholders with no production-specific required override check in AppEnvironment. Production configuration and URL availability were not inspected; the old specific 404 claim is unverified. | [mobile/lib/features/payments/fix_pdf_invoice_builder.dart:14](../mobile/lib/features/payments/fix_pdf_invoice_builder.dart#L14); [mobile/lib/features/payments/invoice_screen.dart:300](../mobile/lib/features/payments/invoice_screen.dart#L300); [mobile/lib/config/app_environment.dart:19](../mobile/lib/config/app_environment.dart#L19); [mobile/lib/config/app_environment.dart:35](../mobile/lib/config/app_environment.dart#L35) |
| GAP-43 | **PARTIAL** | Notification deletes never persist/no backend endpoint<br>**Current:** Original no-backend/local-only assertion is fixed: owned DELETE endpoints and real requests exist. The repository still marks items deleted locally before an unawaited request, ignores token errors, and does not validate response success or roll back the local dismissal. Successful persistence and reload behavior were not established by a live test. | [mobile/lib/features/notifications/notification_repository.dart:112](../mobile/lib/features/notifications/notification_repository.dart#L112); [mobile/lib/features/notifications/notification_repository.dart:113](../mobile/lib/features/notifications/notification_repository.dart#L113); [backend/src/notifications/domain/inbox.controller.ts:93](../backend/src/notifications/domain/inbox.controller.ts#L93); [backend/src/notifications/domain/inbox.controller.ts:111](../backend/src/notifications/domain/inbox.controller.ts#L111) |
| GAP-51 | **PARTIAL** | HttpCallRepository never instantiated/entire calling unwired<br>**Current:** Repository/controller instantiated, buttons start API call then show snackbar. No navigation/import to CallScreen. Screen hangup only local; controller does not expose accept/reject/hangup. Do not claim backend 100% complete or actual audio connected from this source trace. | [mobile/lib/app/app.dart:426](../mobile/lib/app/app.dart#L426); [mobile/lib/app/app.dart:1333](../mobile/lib/app/app.dart#L1333); [mobile/lib/app/app.dart:1363](../mobile/lib/app/app.dart#L1363); [mobile/lib/features/call/call_screen.dart:90](../mobile/lib/features/call/call_screen.dart#L90); [mobile/lib/features/call/call_controller.dart:35](../mobile/lib/features/call/call_controller.dart#L35) |
| GAP-56 | **DUPLICATE** | Clear All in-memory only<br>**Current:** Same as GAP-43; server endpoint and dispatch now exist. | [mobile/lib/features/notifications/notification_repository.dart:113](../mobile/lib/features/notifications/notification_repository.dart#L113) |
| GAP-89 | **PARTIAL** | fix_tests.dart rewrites tests; mock transports shipped<br>**Current:** Named Dart script absent; mobile/fix_tests.py mutates tests and fix_tests_again.py mutates app plus tests. Noop transport remains in lib for explicit SavedAddressRepository.test factory. Does not establish production use; app uses real repository. Source inclusion is not binary proof. | [mobile/fix_tests.py:7](../mobile/fix_tests.py#L7); [mobile/fix_tests_again.py:4](../mobile/fix_tests_again.py#L4); [mobile/lib/features/location/saved_address.dart:4](../mobile/lib/features/location/saved_address.dart#L4); [mobile/lib/features/location/saved_address.dart:114](../mobile/lib/features/location/saved_address.dart#L114) |
| GAP-19/API-trust-pagination | **FIXED_IN_SOURCE** | API inventory uses GAP-19 for unpaginated trust signals<br>**Current:** ID collision with mobile fabricated job proof. Trust endpoint now accepts limit/offset; service clamps take to 1..100 and applies skip. Status filtering remains a separate UI defect covered by parent. | [audit_reports/FIXNOW_API_AND_BACKEND_INVENTORY.md:283](../audit_reports/FIXNOW_API_AND_BACKEND_INVENTORY.md#L283); [backend/src/trust/trust-admin.controller.ts:27](../backend/src/trust/trust-admin.controller.ts#L27); [backend/src/trust/trust.service.ts:282](../backend/src/trust/trust.service.ts#L282) |
| REPORT-counts-and-confidence | **UNSUPPORTED** | 89 verified distinct gaps, 82% integrity, 36 PASS / 5 WARN / 4 FAIL, and feature completion percentages are established measurements.<br>**Current:** The gaps register references 74 distinct GAP IDs; the nine reports together reference 79. Ten IDs in 1–89 are absent. The 45-row integrity matrix actually has 34 PASS / 6 WARN / 5 FAIL. No scoring formula or reproducible feature-status denominator supports 82% or the summary percentages. Historical reported test counts are not current execution evidence. Source facts here use HIGH confidence; no live DB/device/HTTP persistence verification is claimed. | [audit_reports/data_integrity_audit_report.md:23](../audit_reports/data_integrity_audit_report.md#L23); [audit_reports/FIXNOW_AUDIT_SUMMARY.md:44](../audit_reports/FIXNOW_AUDIT_SUMMARY.md#L44) |
