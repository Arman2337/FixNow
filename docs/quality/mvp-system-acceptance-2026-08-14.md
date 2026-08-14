# FixNow MVP System Acceptance Report

Date: 2026-08-14
Task: FN-087
Branch: `fix/local-booking-schema`

## 1. Executive Summary

**NOT MVP READY**

A real customer can register, verify with the explicitly enabled development-only OTP, restore a session, grant foreground location, create exactly one service request, see it persisted, and sign out on the connected Android phone. Backend matching, atomic acceptance, lifecycle, authorization, cancellation, realtime authorization, and ephemeral-location rules have meaningful automated coverage.

The connected marketplace journey nevertheless stops at `REQUESTED`. No backend provider job-feed/read endpoint and no provider incoming-request screen expose an eligible unassigned request. The provider therefore cannot discover its booking ID or accept through the product. Additionally, the Flutter app has no WebSocket client, no concrete tracking source, no provider location publisher, and no production route to the existing tracking screen. Customer/provider synchronization and live tracking are backend-only capabilities, not connected product features.

## 2. Environment

| Item | Value |
| --- | --- |
| OS | Windows (PowerShell workspace) |
| Date/time zone | 2026-08-14, Asia/Calcutta |
| Flutter | 3.38.9 stable, revision `67323de285` |
| Dart | 3.10.8 |
| Node | v22.14.0 (repository minimum is Node 20.9+) |
| PostgreSQL | Local Docker PostgreSQL, loopback `127.0.0.1:55432`; disposable `fixnow_test` database for integration tests |
| Redis | Local Docker Redis, loopback `127.0.0.1:56379` |
| Test device | Physical Nothing A059, Android, 1080×2392 at density 420, USB serial redacted from report |
| Backend URL | `http://127.0.0.1:3300/api/v1/`, forwarded to Android with `adb reverse` |
| Mobile build | Flutter debug, `APP_ENV=development`, local OTP UI explicitly enabled |
| Test data | Generated `example.test` customer; no production/staging data or real documents |

The local development database was not reset. Destructive integration cleanup ran only against the guarded `fixnow_test` role/database. The audit created one synthetic development booking and did not delete data or volumes.

## 3. Automated Validation

| Check | Result | Evidence |
| --- | --- | --- |
| Flutter analyze | PASS | No issues found |
| Flutter tests | PASS | 55/55 |
| Flutter build | PASS | Debug APK built |
| Backend lint | PASS | ESLint completed |
| Backend unit tests | PASS | 46 suites, 213 tests |
| Backend integration tests | PASS | 9 suites, 40 tests on guarded `fixnow_test` |
| Backend build | PASS | Nest build completed |
| Backend generic E2E smoke | FAIL | 0/1; harness omits the configured `WsAdapter`, so Nest exits before the assertion |
| Realtime/location tests | PASS (automated only) | 12 focused unit tests are included in the 213; live mobile client is absent |
| Admin lint/type-check | PASS | ESLint and TypeScript completed |
| Admin tests | PASS | 6 files, 11 tests |
| Admin build | PASS | Next.js production build; 10 application routes generated |

The first generic E2E attempt also inherited local `LOCAL_OTP_BYPASS_ENABLED=true` while Jest uses `NODE_ENV=test`; explicitly disabling the flag reached the separate WebSocket-adapter harness failure. The running development API itself passed readiness with HTTP 200.

## 4. Customer Journey

| Step | Result | Evidence |
| --- | --- | --- |
| Registration | PASS | Fresh synthetic account created on physical phone |
| Verification | PASS | Normal challenge plus development-only `000000`; production/test bypass remains rejected by config |
| Login | PASS | Verification session reached customer shell; role routing covered by tests |
| Duplicate registration | PASS | Backend unit/integration coverage; API returns generic conflict behavior |
| Invalid email/password/OTP | PASS (automated) | Auth validation and lifecycle suites |
| Session restore | PASS | Force-stop/relaunch returned to customer Home |
| Service discovery | PASS | Active categories loaded on phone |
| Request creation | PASS | One Plumbing request created on phone |
| Location | PASS WITH LIMITATIONS | Foreground precise grant worked; denial widget covered; FN-085 fallback matrix is not implemented |
| Matching | PARTIAL | Eligibility query works in integration tests; no persisted/offered provider experience |
| Booking list | PASS | Synthetic booking shown as `REQUESTED` after navigation |
| Booking details | PARTIAL | Reachable and honest; no provider projection, cancel action, or live data |
| Tracking | FAIL | Tracking classes are unreachable and have no concrete API/WebSocket source |
| Cancellation | NOT IMPLEMENTED IN MOBILE | Backend policy works; no customer action (FN-090) |
| Completion/history | BLOCKED | History can render states, but provider cannot discover/accept the request |
| Profile | PASS | Reachable; automated update/validation coverage; location excluded |
| Support | PARTIAL | Honest unavailable preview; FN-075 remains in progress |
| Logout | PASS | Physical phone returned to Welcome |

The synthetic request produced exactly one booking (`b5c9c164-ffe8-4449-9deb-c2c136c971d6`) at status `REQUESTED`, version 1, and exactly one booking event. The report intentionally omits identity credentials, session material, and coordinates.

## 5. Provider Journey

| Step | Result | Evidence |
| --- | --- | --- |
| Registration/login | PASS (automated/source; prior physical provider evidence) | Role-aware auth and applicant routing exist |
| Onboarding profile | PASS | Reachable profile/service-area form and backend contract |
| Skills | PASS WITH LIMITATIONS | Claim/add UI exists; verification remains reviewer controlled |
| Service area | PASS WITH LIMITATIONS | Foreground current location only; precise value hidden in UI |
| Documents | PARTIAL | Private upload/list contract and UI exist; no live harmless-file upload in this run |
| Verification status | PASS | All application states render honestly |
| Reviewer approval | PASS backend/source; NOT TESTABLE LIVE | Admin UI/contracts exist, but no documented local reviewer fixture was available |
| Availability | PASS (automated/source) | Online/offline and weekday schedule are integrated |
| Incoming requests | FAIL | No endpoint, controller route, repository method, or mobile screen |
| Acceptance | PARTIAL | Backend command/race tests pass; no discoverable product path |
| Active job | PARTIAL | Assigned-job commands exist; no normal way to obtain assignment |
| Lifecycle | PARTIAL | Backend and mobile buttons support `ASSIGNED → EN_ROUTE → IN_PROGRESS → COMPLETED`; full app E2E blocked |
| History | PASS for already-assigned records | `GET /bookings` returns participant history and mobile renders it |
| Profile/logout | PASS (source/automated) | Reachable by role |

## 6. Critical Customer → Provider Journey

| Acceptance point | Result | Evidence |
| --- | --- | --- |
| Customer A created booking | PASS | Physical Android + database/event verification |
| Provider matching found eligible provider | PASS (backend integration) | Matching excludes wrong status/skill/area/availability and hides coordinates |
| Provider saw request in app | FAIL | No provider request feed or screen |
| Provider accepted request | FAIL end to end / PASS backend | Atomic acceptance tested, but booking ID is undiscoverable in product |
| Customer saw acceptance | BLOCKED | No acceptance can occur through provider app; customer uses HTTP refresh, not realtime |
| Provider set En Route | BLOCKED end to end / PASS backend automation | Requires assigned booking |
| Live location visible appropriately | FAIL mobile / PASS backend unit rules | Mobile does not connect to WebSocket or publish/consume locations |
| Provider arrived | NOT IMPLEMENTED AS DISTINCT STATE | Authoritative contract transitions from `EN_ROUTE` to `IN_PROGRESS` |
| Work started | BLOCKED end to end / PASS backend automation | `IN_PROGRESS` legal transition exists |
| Work completed | BLOCKED end to end / PASS backend automation | `COMPLETED` legal transition exists |
| Customer history updated | BLOCKED end to end | HTTP history supports it after backend transitions |
| Provider history updated | BLOCKED end to end | Assigned history supports it after backend transitions |

## 7. Screen Inventory

The detailed route/source/backend/test matrix is maintained in [`../design/screen-inventory.md`](../design/screen-inventory.md). It contains 34 audited mobile/admin surfaces: 21 existing screens or compositions, 6 partial/unreachable core/support surfaces, 4 missing core integrations, and 3 explicit future admin/roadmap surfaces. Counts group composed functionality (for example availability within Provider Home) rather than Dart classes.

## 8. Working Screens

Fully working for their currently supported contract (18): Welcome, Role selection, Registration/sign in, Email verification, Session restore, Customer Home/categories, Location consent, Service request, Booking list, Customer profile, Provider registration, Provider verification status, Provider Home, Availability/schedule, Provider history, Admin dashboard/shell, Admin user management, and Admin service management.

Admin/provider-review and provider operational screens pass source/build/automated validation but were not all manually authenticated in this run; they are therefore not counted as fully live-accepted.

## 9. Partial Screens

- Booking details: honest status/detail, but no cancel/provider/live projection (FN-089, FN-090).
- Help: honest preview; no support submission (FN-075).
- Professional setup: profile/skills/documents exist; no applicant self-submit transition.
- Active assigned job: lifecycle controls exist, but assignments cannot originate from the provider product (FN-088).
- Provider profile: reuses onboarding composition and lacks a dedicated verified-provider edit experience.
- Admin provider review: source/contracts/tests exist; live acceptance blocked by absent documented reviewer fixture.

## 10. Missing Screens

### Core MVP

- Provider incoming eligible-request list (FN-088).
- Provider request detail/acceptance (FN-088).
- Reachable customer realtime tracking and status synchronization (FN-089).
- Provider presence/consent/live-location controls (FN-089).

### Supporting MVP

- Customer/provider booking cancellation actions (FN-090).
- Complete Help/support submission (FN-075).
- Dedicated provider profile editing and richer completion presentation.

### Future Roadmap

Payments, invoices/refunds, provider earnings, ratings/reviews, AI/voice/image assistance, push notifications, emergency dispatch, complaints, and analytics.

## 11. Backend Without Mobile UI

- Atomic provider acceptance exists, but no eligible-request read/discovery contract exposes a booking to providers.
- Authorized WebSocket booking subscriptions, presence, location consent, location ingestion, TTL, and projections exist, but Flutter has no WebSocket integration.
- Booking cancellation exists for customer/provider/admin, but no mobile action exists.
- Admin provider decisions exist and have a Next.js UI; local manual acceptance lacks a documented reviewer fixture.

## 12. UI Without Backend Support

- Help is deliberately an unavailable preview while FN-075 is active; it does not falsely claim submission.
- Tracking UI classes imply live/offline states but are unreachable and lack a concrete backend source.
- Booking detail correctly says provider identity/ETA/map are unavailable; there is no customer-safe assigned-provider read model supplying them.

No hardcoded provider, earnings, ratings, price, or booking data was found in production mobile paths.

## 13. Real-Time Results

- WebSocket backend: boots in the real app with the `ws` adapter; authorization, heartbeat, limits, subscription ownership, presence, consent, location validation, TTL, and projection logic exist.
- Mobile connection: MISSING; no WebSocket package/client or production instantiation.
- Booking updates: HTTP reload on booking screen, not automatic synchronization.
- Provider presence/location: backend-only; no mobile frames are sent.
- Reconnect/stale behavior: controller unit logic exists, but no concrete client means it is not product behavior.
- Location cache: no keys were present after the audit; implementation tests verify one latest point with a 60-second TTL and invalidation.

## 14. Security / Privacy Findings

- Customer/provider history is participant-scoped; provider projections redact booking coordinates.
- Matching returns provider IDs and distance, not exact provider coordinates.
- Cross-role/resource authorization, stale versions, acceptance races, cancellation ownership, and illegal transitions have automated coverage.
- All 4 local credentials inspected were Argon2id hashes; all 9 local refresh-session records used 64-character hashes. OTP storage has only `code_hash`, not a raw-code column.
- Booking events are append-only via a database mutation-prevention trigger.
- No Redis values, tokens, OTPs, passwords, or coordinates were printed into evidence.
- Production readiness remains blocked by unresolved policy/operational/security release gates documented in product/security requirements.

Not testable in this run: live cross-user WebSocket channel isolation with two mobile sessions, document-object privacy via real fixture upload, 200% text-scale physical walkthrough, small/large physical form factors, cache outage behavior, and a live admin reviewer login.

## 15. Known MVP Blockers

### BLOCKER-01 — Provider cannot discover customer requests

- Severity: RELEASE BLOCKER
- Evidence: only participant history `GET /bookings` exists; unassigned bookings have no provider participant. Flutter calls only that assigned-history endpoint.
- Affected flow: request → provider discovery → acceptance.
- Task: FN-088.

### BLOCKER-02 — Mobile realtime and live location are disconnected

- Severity: RELEASE BLOCKER
- Evidence: no Flutter WebSocket client or concrete `BookingTrackingSource`; tracking screen is unreachable; provider emits no presence/consent/location frames.
- Affected flow: synchronized acceptance/lifecycle and live tracking.
- Task: FN-089.

## 16. Non-Blocking Issues

- HIGH: No customer/provider cancellation UI despite working backend policy (FN-090).
- HIGH: Generic backend E2E smoke harness does not install `WsAdapter`; its only test fails before assertion (FN-091).
- MEDIUM: Help is an honest preview (FN-075).
- MEDIUM: No documented local reviewer fixture prevented live admin approval acceptance (FN-092).
- MEDIUM: Location current-fix failure has no bounded last-known fallback; FN-085 was correctly cancelled because it was not the booking 500 root cause, so the requested failure matrix remains unimplemented (FN-093).
- LOW: Provider Profile reuses onboarding presentation.

## 17. Roadmap Not Yet Implemented

Payments, invoices, refunds, provider earnings, ratings/reviews, AI chat, voice booking, image analysis, smart pricing, push notifications, emergency dispatch, complaints, analytics, and premium subscriptions are **NOT IMPLEMENTED — ROADMAP**, not current defects.

## 18. Recommended Next Actions

1. Complete FN-088: eligible incoming-request feed, provider request UI, and atomic acceptance.
2. Complete FN-089: authenticated Flutter realtime client, reconciliation, provider location publishing, and reachable customer tracking.
3. Add a deterministic two-user E2E test that creates, discovers, accepts, progresses, completes, and verifies both histories.
4. Complete FN-090 cancellation actions and validate tracking invalidation.
5. Complete FN-092 and rerun provider approval plus admin visual acceptance.
6. Complete FN-091 to install `WsAdapter` in the E2E harness and isolate local environment flags.
7. Finish FN-075 separately; do not delay core marketplace repair for supporting Help work.
8. Complete FN-093 and execute the full denied/disabled/unavailable/stale/inaccurate location matrix.

## 19. Final Verdict

### Can a customer request a service?

**YES.** Proven on a physical Android phone and in the local database.

### Can an eligible provider see that request from the provider app?

**NO.** The incoming-request feed and UI do not exist.

### Can the provider accept it?

**PARTIAL.** Backend acceptance works when a booking ID is supplied, but no provider product path supplies it.

### Does the customer see the provider/status update?

**PARTIAL.** HTTP history can reflect backend changes after refresh; realtime mobile synchronization is absent and the provider cannot accept through the app.

### Can the full booking lifecycle complete?

**PARTIAL.** Backend automation completes it; the connected customer/provider product journey cannot.

### Is FixNow currently MVP-ready for local controlled testing?

**NO for full marketplace acceptance.** Customer-side and isolated backend/provider components can be tested with limitations.

### Is FixNow production-ready?

**NO.** Core product integrations and documented production release gates remain incomplete.
