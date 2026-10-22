# FixNow Full Runtime QA Analysis — 2026-10-20

**Single consolidated analysis file.** Covers the complete dual-device runtime A–Z test (customer + provider mobile roles) and the follow-up cross-surface workflow test (customer on mobile via Quick Login, provider on the desktop web app via Quick Login, full booking lifecycle accept → complete).

- **Method**: 100% runtime evidence — real app on real devices / real browser, real local backend, real Postgres. Screenshots per step; every UI claim cross-checked against DB ground truth and live backend logs. No code-analysis-only conclusions (source was read only to explain observed failures).
- **Evidence**: `QA/device-testing-2026-10-20/customer/screens/` and `QA/device-testing-2026-10-20/provider/screens/` (mobile), browser screenshots (web), live backend request log, psql dumps.
- **Test plan**: `QA/device-testing-2026-10-20/TEST_PLAN.md`.

---

## 1. Environment

| Item | Value |
| --- | --- |
| Device A | Realme RMX3201 · Android 11 (API 30) · 720×1600 · adb `MF6HBIVOUS9PQSF6` |
| Device B | Motorola edge 60 stylus · Android 16 (API 36) · 1220×2712 · adb `ZA222YVHZV` |
| Mobile app | `flutter build apk --debug` · APP_ENV=development · API_BASE_URL=http://127.0.0.1:3300/api/v1/ · LOCAL_OTP_BYPASS_ENABLED=true |
| Desktop web app | Flutter web (same codebase) · debug build · served locally, opened in QA browser |
| Backend | NestJS dev server :3300 (Postgres 18 `fixnow`, Redis) |
| Network | `adb reverse tcp:3300` per device |
| Test accounts | Customer: Rohan Thakar `+919876543212`; Provider: Mahesh Verma `+919876543211`; plus Quick Login fixtures Customer A / Provider A (see §5) |

**Role-swap note**: mid-run the Motorola became the primary driver for *both* mobile roles (Realme unusable at 720p, F-01). Therefore `provider/screens/040–079` are customer-role shots and `customer/screens/060–084` are provider-role shots.

---

## 2. Mobile Customer Journey (Motorola) — passed steps

| Step | Result | Evidence |
| --- | --- | --- |
| Welcome → role → sign-in (OTP bypass) | PASS | `customer/screens/003–012` |
| Home discovery grid from API | PASS | `013–018` |
| Catalog → AC Jet Foam ₹499 → cart ₹588.82 | PASS | `019–031` |
| Request Service → address sheet → schedule → submit | PASS | `032–058` |
| Booking `607901ea-…` in DB (REQUESTED, ₹588.82, GPS 12.9352/77.6245) | PASS | DB |
| 5-min unmatched auto-cancel with explicit reason, nothing charged | PASS | booking row, `in_app_notifications` |
| Profile edit persisted (`Rohan T.g`), push toggles, logout | PASS | `080–084` |

## 3. Mobile Provider Journey (Motorola) — passed steps

| Step | Result | Evidence |
| --- | --- | --- |
| Register → OTP auto-fill → verified | PASS | `060–072` |
| Partner Verification dashboard renders | PASS | `098,114` |
| Display Name + Bio → Save Profile → `provider_profiles` row | PASS | `117–121` |
| Add Skill (HVAC) → `provider_skills` row | PASS | `122–123` |
| Submit for Final Review → application `under_review` | PASS | `124` |
| Sign Out button → welcome (no confirmation) | PASS | `128` |

## 4. Cross-device lifecycle (mobile↔mobile) — blocked, root-caused

The provider-accepts-booking lifecycle could not be reached on two phones, for a verified product-reason chain:
1. KYC upload `POST /provider-documents/aadhaar` → **400** on every attempt, silently swallowed by UI (F-15) → `provider_documents` empty.
2. App still accepts "Submit for Final Review" with 0/4 docs (F-29) → `under_review`.
3. Provider app then traps the user on Partner Verification — no dashboard/availability/job feed until admin approval.
4. Approval needs the admin console/API; live DB admin has no documented password; the official acceptance-fixture seeder is hard-guarded to `fixnow_dev`/`fixnow_test` and refuses the live `fixnow` DB (F-21 chain).
5. Customer bookings auto-cancel after 5 min with no available provider (backend behavior correct).

**Conclusion (P0)**: with only the two mobile apps on a fresh local install, the core marketplace loop is unreachable. → motivating the follow-up cross-surface test in §5–§6, which unblocks the loop via the documented Quick Login fixtures.

---

## 5. Follow-up: cross-surface workflow test setup

Goal: customer on **mobile** (Motorola) + provider on **desktop web app**, both via **Quick Login**, then drive a booking accept → complete.

### 5.1 Fixture accounts (Quick Login identities)
The debug build's auth screen has `⚡ Quick Login (Customer A)` / `⚡ Quick Login (Provider A)` buttons which submit:
- Customer A: `fixnow.acceptance.customer-a@local.test` / `FixNow-local-customer-a-2026!`
- Provider A: `fixnow.acceptance.provider-a@local.test` / `FixNow-local-provider-a-2026!`

These identities did **not exist** in the live `fixnow` DB (F-21: the button401s silently). The official seeder (`backend/test/acceptance-fixtures.ts`) refuses the live DB by design (`src/auth/acceptance-fixture-guard.ts`: loopback + `fixnow_dev`/`fixnow_test` only). To exercise the workflow the identities were installed into the live local `fixnow` DB with a faithful standalone seeder: `backend/scripts/seed-live-fixtures.js` (same rows/credentials as the official fixtures: users, argon2 `auth_credentials`, `user_roles`, approved `provider_applications`, `provider_profiles` (Kathlal, Gujarat base), `provider_skills` (all categories), `provider_availability` = online 2h). This is a **test-fixture action, not an app change** — mirrors `npm run test:acceptance:seed`, only pointed at the live dev DB.

### 5.2 Desktop web app serving
The backend has **no CORS middleware** (`WEB_ALLOWED_ORIGINS` unset → preflight404s), so the Flutter web app is served **same-origin from :3300** via an adb-style local forward, avoiding cross-origin entirely. (This is the same origin the mobile app reaches via `adb reverse`.)

---

## 6. Cross-surface workflow run — customer (mobile) × provider (web)
*(appended during execution — see §7 for the findings this run adds)*

## 7. Findings register (F-01 … F-30+)
*(see the master findings table below; new findings from the workflow run are numbered F-31+)*
