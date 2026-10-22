# FixNow Dual-Device Runtime Test Plan (A–Z)

**Date**: 2026-10-20
**Method**: 100% runtime, two physical devices over USB + local backend. No code analysis used as test evidence; repository docs/DB used only to know WHAT to click and to verify screen data against its source of truth.
**Evidence**: per-step screenshots in `QA/device-testing-2026-10-20/customer/screens` and `.../provider/screens`; backend request log captured live during tests.

## Environment
| Item | Value |
| --- | --- |
| Device A (customer role) | Realme RMX3201 · Android 11 (API 30) · 720x1600 · adb `MF6HBIVOUS9PQSF6` |
| Device B (provider role) | Motorola edge 60 stylus · Android 16 (API 36) · 1220x2712 · adb `ZA222YVHZV` |
| App build | `flutter build apk --debug` · APP_ENV=development · API_BASE_URL=http://127.0.0.1:3300/api/v1/ · LOCAL_OTP_BYPASS_ENABLED=true |
| Backend | NestJS dev server on :3300 (Postgres 18 `fixnow` DB, Redis) |
| Network path | `adb reverse tcp:3300` on both devices (device's 127.0.0.1:3300 → host :3300) |

## Test Matrix — Customer (Device A)
1. Cold launch → Welcome screen renders.
2. Role selection → Customer.
3. Sign in (existing +919876543210) via OTP; OTP bypass hint visible in dev.
4. Home / discovery: category grid loads from API (verify against DB service_categories).
5. Notifications icon/badge, search, bottom nav each tab (click all).
6. Open catalog (e.g., Plumbing) → sub-services & prices from DB; cart itemizer: add/remove items.
7. Service request flow: address selector (add/delete address), schedule picker (windows), placeholder notes field.
8. Emergency/SOS entry if present; FixAI diagnostic entry (click, note disabled/real state).
9. Submit booking → match radar/waiting → (provider device accepts) → match celebration.
10. Live tracking screen: map/status/OTP + provider messages/chat; audio call entry.
11. Bookings hub tabs (Active/History), open booking detail, timeline.
12. Reschedule flow, cancel flow (on a second booking).
13. Chat send/receive messages. Call initiate/end.
14. Complete job flow (provider device) → invoice screen data vs DB invoices; payment entry (note provider=none).
15. Review flow: 5-star + photos; verify rows in DB booking_reviews.
16. Profile & settings pages: edit display name, addresses, push notifications card, logout.
17. Help & support hub; complaints flow end-to-end; complaints list.
18. Notification center: mark read, clear.

## Test Matrix — Provider (Device B)
1. Cold launch → Welcome → Pro role.
2. Register new provider account (+919876543211) via OTP.
3. KYC onboarding form fields; skills; documents; submit application (verify DB provider_profiles/applications state; if gated, record exact blocker).
4. Provider home workspace; toggles (availability/status); verify API side-effect in DB.
5. Jobs & schedule ledger tabs.
6. Available bookings feed; accept the customer booking → verify both devices reflect state.
7. Job cockpit: start with service-start-OTP flow (customer shows OTP), statuses advance.
8. Messages/call actions; job proof photos upload if functional.
9. Earnings ledger; verify amounts vs DB invoices/earnings endpoint.
10. Profile/settings/logout.

## Cross-Cutting Checks (both roles)
- **Mock-data sweep**: every screen's numbers/names/categories cross-checked against DB at test time; screenshot pairs recorded for any value that cannot be traced to origin.
- **Role leakage / wrong screens**: customer should never see provider-only screens & vice-versa; check nav and deep links by relaunching app per role.
- Error paths: submit with empty fields, wrong OTP, cancel bookings, network behavior of dev build.
---

## Findings
(To be appended during the run: F-01, F-02, ... each with severity + evidence path.)

---

# RUN REPORT — executed 2026-10-20, 09:50–14:35 IST

## Execution notes (deviations from plan)
- **Roles swapped mid-run**: the Realme (720×1600) cannot render/interact with several core screens (F-10), so the Motorola became the **primary driver for both roles** (customer session first, then provider session), and the Realme served as secondary evidence device. Screenshot directories therefore contain **both roles** for the Motorola era: `provider/screens/040–079` are *customer*-role shots, `customer/screens/060–084` are *provider*-role shots. All later provider onboarding evidence (098–128) is on the Motorola in `provider/screens/`.
- Customer account: Rohan Thakar · +91 9876543212 · `rohan.thakar@fixnowtest.com` (registered in-run; display name later edited to "Rohan T.g").
- Provider account: Mahesh Verma · +91 9876543211 · `mahesh.verma@fixnowtest.com` (registered in-run via OTP bypass).
- Backend log captured live; DB (`fixnow`, Postgres 18) cross-checked with psql after every state change.

## Customer journey — what passed (DB-verified)
| Step | Result | Evidence |
| --- | --- | --- |
| Welcome → role select → sign-in (OTP bypass) | PASS | `customer/screens/003–012` |
| Home discovery grid + categories from API | PASS | `013–018` |
| Catalog → AC Jet Foam ₹499 → cart ₹588.82 | PASS | `019–031` |
| Request Service form → address sheet → schedule → submit | PASS | `032–058` |
| Booking `607901ea-e483-49ae-a91e-1234e83b1710` in DB: REQUESTED, items/₹588.82, GPS 12.9352/77.6245 | PASS | DB row |
| Auto-cancel after 5-min unmatched timeout w/ explicit reason + "nothing was charged" | PASS | `in_app_notifications`, booking row (cancelled 11:21:58) |
| Profile: display-name edit persisted (`customer_profiles.display_name='Rohan T.g'`) | PASS | `080–084` |
| Logout, push toggles, footer "v2.4.1 Build 492 • ISO 27001" | PASS | `080–084` |

## Provider journey — what passed (DB-verified)
| Step | Result | Evidence |
| --- | --- | --- |
| Register via Create Account → OTP auto-fill → verified | PASS | `customer/screens/060–072` (Realme), re-done on Moto |
| Partner Verification dashboard renders (Step 1 of 4, doc cards) | PASS | `provider/screens/098,114` |
| Display Name + Bio → Save Profile → `provider_profiles` row created (13:39, 200) | PASS | `117–121`, DB row |
| Add Skill → HVAC chip → `provider_skills` row (category ab749147…) | PASS (persistence) | `122–123`, DB row |
| Submit for Final Review → `provider_applications.status='under_review'` (13:49) | PASS (persistence) | `124`, DB row |
| Sign Out button → returns to welcome | PASS (but no confirm — F-23) | `128` |

## Customer↔Provider cross-device interplay — BLOCKED, root-caused
The full lifecycle (provider accepts → en route → START PIN → complete → invoice → rating) **could not be reached at runtime**, for a chain of product reasons, each individually verified:
1. KYC document upload (`POST /api/v1/provider-documents/aadhaar`) returns **400** on every attempt (2×, 35 KB and 13 KB multipart) while the UI shows no error and no state change (F-xx below) → `provider_documents` stays empty.
2. With 0 of 4 verified, the app still **accepts "Submit for Final Review"** (F-29) → application `under_review`.
3. The provider app then traps the user on Partner Verification — **no dashboard, no availability toggle, no job feed** until an admin approves (Trust card states approval unlocks the dashboard). There is no admin surface in the mobile app.
4. Approval requires the admin console/API. The live DB's seeded admin (`admin.qa@fixnow.local`, operations_administrator) has **no documented password** anywhere in the repo; the documented acceptance-fixture identities (`docs/testing/local-acceptance-fixtures.md`) are hard-guarded to loopback `fixnow_dev`/`fixnow_test` databases and refuse the live `fixnow` DB by design (`acceptance-fixture-guard.ts`). The in-app "⚡ Quick Login (Provider A)" button therefore prefills an account that does not exist here → 401 swallowed silently (F-21).
5. Meanwhile customer bookings auto-cancel after 5 minutes with no provider available (correct backend behavior, verified).

**Conclusion**: on a fresh local install driven only by the mobile apps, the marketplace's core loop is **unreachable**: no provider can become approved, so no booking can ever be accepted. This is a P0 product finding, not a test gap.

---

## FINDINGS REGISTER (F-01 … F-30)

| ID | Sev | Finding | Evidence |
| --- | --- | --- | --- |
| F-01 | P0 | **720p scroll/hit-test systemic failure**: on Realme (720×1600) multiple core screens overflow and cannot be scrolled or interacted with; provider KYC is fully unusable. App is effectively broken on common low-res devices. | `customer/screens/060–084`, Realme parked on KYC |
| F-02 | P1 | **Live tracker never updates**: customer booking screen froze at "Finding a pro nearby" / "Live updates paused" (websocket gap); the auto-cancel at 11:21:58 never surfaced to the open customer app. | `050–058`, booking row |
| F-03 | P1 | **Fabricated provider state shown to customer**: tracker card rendered "Provider Assigned ✓ / START PIN" while DB `provider_id` was NULL. UI invents lifecycle elements that don't exist. | `059`, DB row |
| F-04 | P2 | OTP dev-bypass hint + Quick-Login phantom accounts shipped in the customer auth flow; Quick Login prefills a non-existent `fixnow.acceptance.*` account → 401 with **no message** and a silent tab reset. | `067–069`, backend log 401 |
| F-05 | P2 | Password field renders a stray trailing character while masking (dots + visible last char artifact). | `111`, `112` |
| F-06 | P1 | **Address save silently fails**: `POST /users/me/addresses` → 400, but UI shows "Home DEFAULT" saved; `customer_addresses` has 0 rows; the address later renders as "(Near ), –". | `040–044`, backend log |
| F-07 | P2 | GPS "use current location" button on the request form is a **silent no-op** (no API call, no error). | `048`, backend log |
| F-08 | P2 | Footer claims "v2.4.1 Build 492 • ISO 27001" — unverifiable marketing/certification claims rendered in a dev build. | `084` |
| F-09 | P1 | **Cross-role screen leakage (structural)**: the provider app renders the *customer* registration copy ("Register your home…") in the provider registration flow. | `060–063` |
| F-10 | P0 | See F-01 (same root cause, customer side: booking/checkout screens overflow at 720p). | Realme shots |
| F-11 | P2 | Login form: IME "done" key **clears entered credentials** instead of submitting/dismissing. | `072` |
| F-12 | P2 | Moto call-chip env oddity (dialer integration renders inconsistently). | `077` |
| F-13 | P1 | Notification inbox of **provider shows customer's booking notification** (see F-25, duplicate pointer). | `115` |
| F-14 | P2 | Bookings hub shows "JOB IN PROGRESS" pill + matching-specialists card with mock-looking provider thumbnails on a cancelled/absent booking. | `059`, `083` |
| F-15 | P1 | **KYC upload 400 swallowed**: `POST /api/v1/provider-documents/aadhaar` returns 400 (JSON body, 209 B) on every attempt; UI shows no error, no spinner-end state, no card change. `provider_documents` remains empty. | `101–105`, backend log 12:56 & 13:00 |
| F-16 | P2 | File picker for "Attach PDF" opens with a **loose MIME filter** — image thumbnails (screenshots) shown in a PDF-only flow. | `101` |
| F-17 | P1 | **Cross-user notification leak (critical)**: `in_app_notifications` contains exactly ONE row — user `4ebd249a…` (customer Rohan), kind `booking:customer:CANCELLED` — yet it renders in the **provider's** inbox ("Active Bo… #607901EA — Your booking was cancelled"). The notifications API is not filtering by the authenticated user (IDOR-class data isolation failure; exposes booking IDs between unrelated users). | `115`, DB row |
| F-18 | P1 | **Fake-address delete 500s server-side**: `DELETE /users/me/addresses/addr-1792475094475` → **500** (backend crash on unknown ID) while the client UI showed the delete as successful. | backend log 11:48 |
| F-19 | P1 | Customer tracker shows "Provider Assigned ✓ / START PIN" for a booking with `provider_id NULL` (same as F-03; tracked separately as it is also a wrong-role render). | `059` |
| F-20 | P2 | Accidental tap on the provider avatar chip logs the user out **with no confirmation**; the welcome screen then defaults to **Customer** role (role not remembered). | `106–108`, `128` |
| F-21 | P2 | Quick Login (Provider A) prefills a phantom account → 401 silently swallowed, no error message, tab silently resets. | `067–069` |
| F-22 | P1 | Flutter "RIGHT OVERFLOWED BY 57/82/36/54 PIXELS" stripes on the 720p provider KYC screen (root cause of F-01). | `060–084` |
| F-23 | P2 | Delete address from client with **no confirmation dialog** (data loss UX). | `082` |
| F-24 | P2 | Step checklist circles ("1. Bio Info", "2. Trade Skills", …) are **decorative-only** — look interactive (progress indicators) but are not clickable; no affordance explains this. | a11y dump + `098` |
| F-25 | P0 | See F-17 (cross-user notification leak). | `115`, DB |
| F-26 | P2 | Provider avatar chip logout path (same as F-20). | `106` |
| F-27 | P1 | **False trust statement**: Trust & Safety card claims "Your documents are currently being audited by FixNow Trust Operations. Approval turnaround: 24 hours" while **0 of 4 documents were ever uploaded** (`provider_documents` empty). Also `provider_skills.is_verified = t` set immediately for an unaudited provider. | `116`, `123`, DB rows |
| F-28 | P1 | **Provider base location is 0,0 (Null Island)**: `provider_profiles.base_latitude/longitude = 0,0`; the UI claims "Covers: Selected radius around your base location" — meaningless; providers would never match. No location-capture step in onboarding. | DB row |
| F-29 | P1 | **Required-document gate not enforced**: "Submit for Final Review" accepted with 0 of 4 required docs uploaded; application transitioned to `under_review` instead of erroring. | `124`, DB row |
| F-30 | P1 | **Dispatch-radius slider is decorative**: dragging fires an auto-save `PUT /provider-profile/me` that returns **400** (no UI error), and "Save Updates" reports "Updates saved successfully" but sends only the original name+bio payload (138 B, identical to the first save). DB retains 12 km while the UI displays 26 km. | `125`, `127`, backend log 13:51 & 14:29, DB row |

## Severity summary
- **P0 (blocker)**: 3 — F-01/F-10 (720p unusable), F-17/F-25 (cross-user notification data leak), plus the composite "core loop unreachable" root-cause chain (F-15 → F-29 → admin wall).
- **P1 (major)**: 11 — F-02, F-03/F-19, F-06, F-09, F-13, F-15, F-18, F-22, F-27, F-28, F-29, F-30.
- **P2 (minor)**: 12 — F-04, F-05, F-07, F-08, F-11, F-12, F-14, F-16, F-20/F-26, F-21, F-23, F-24.

## What could NOT be tested (blocked by the above, not by effort)
- Provider accepting a live booking; en-route; START PIN/OTP start; job completion; invoice; payment; rating — all require an **approved, online provider**, which is unreachable at runtime (F-15 → F-29 → admin-approval wall with no accessible admin credentials/fixture path).
- Realme (720p) interactions beyond what is in `customer/screens/060–084` — device is unusable for the app (F-01).

## Evidence inventory
- `QA/device-testing-2026-10-20/customer/screens/`: 84 files (003–084; includes Realme provider-role 060–084).
- `QA/device-testing-2026-10-20/provider/screens/`: 91 files (040–128; includes Moto customer-role 040–079).
- Backend request log (live capture) used for every 4xx/5xx cross-check.
- DB ground truth: `bookings`, `customer_profiles`, `customer_addresses`, `provider_applications`, `provider_profiles`, `provider_skills`, `provider_documents`, `in_app_notifications`, `user_roles`.
