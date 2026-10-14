# FixNow — Feature Gaps, Defects & Dead Code

**Audit date:** 2026-10-12 · **Commit:** `3bdb5a2` + 5 uncommitted working-tree fixes
**Companions:** `FEATURE_INVENTORY.md`, `FEATURE_TRACEABILITY.md`

Findings are separated into:

- **§A — Verified defects** — reproduced or directly proven from source + an executed command
- **§B — Verified risks** — proven present in source; impact depends on environment
- **§C — Potential risks** — plausible from code reading; needs targeted investigation
- **§D — Stubs and fabricated data shipped in the product**
- **§E — Dead code and unreachable screens**
- **§F — Missing features**
- **§G — Duplicated / conflicting implementations**
- **§H — Untested and unverified surface**

Severity: **P0** blocks or corrupts production · **P1** serious correctness/security · **P2** important · **P3** polish

> Scope note: five files were modified in a prior session and remain uncommitted (admin parse error, checkout gating, catalog ratings, hotline, dev orchestrator). Those fixes are treated as applied and are **not** re-listed here as defects.

---

## §A — Verified defects

### GAP-01 · P0 · CI gate is red: secret scanner fails on a committed file

**Verified by execution.** `node scripts/scan-secrets.mjs` → `scan-secrets: 1 finding(s)`, **exit 1**.

```
[postgres-url-with-password] backend/src/health/health-dashboard.spec.ts
    PostgreSQL URL carrying an inline password
```

The matching line is `health-dashboard.spec.ts:173` — an `ECONNREFUSED` error string containing a PostgreSQL URL with an inline password for the non-resolving host `db.internal` (user, password, host, and port are elided here; see the source line).

**This is a false positive** — a synthetic error string for a non-resolving host, used to exercise the health dashboard's error rendering. No credential is exposed.

But it matters for two reasons: the file is **tracked** in git, and `.github/workflows/ci.yml:342` runs exactly this command as the `Secrets` job. **CI is currently failing on this gate.** The scanner's self-test (`--self-test`) passes all 11 rules, so the scanner itself is healthy; it simply has no allowance for test fixtures.

**Fix options:** add a `# scan-secrets: allow postgres-url-with-password -- test fixture` marker on the line (if the scanner supports inline allowlists — verify before relying on it), or move the fixture behind a helper the scanner skips. **Do not simply delete the finding from the rule; the rule is correct.**

### GAP-02 · P0 · `seed.js` destroys the sub-service catalog on every production deploy

`render.yaml:7` runs, in sequence, on **every boot**:

```
npm run typeorm -- migration:run -d typeorm.config.ts && node seed.js && npm run start:prod
```

`backend/seed.js:91` executes:

```js
DELETE FROM sub_services          // ← no WHERE clause
```

then reinserts 39 hardcoded rows (`:12-69`). Consequences:

- Any admin-curated sub-service created through `/services` is **destroyed on every deploy**
- There is no `ON CONFLICT`; "idempotency" rests entirely on the preceding delete
- If `DATABASE_URL` is unset, the script silently connects to a local `postgresql://postgres:replace-me@localhost:5432/fixnow` (`:6`) rather than failing

### GAP-03 · P0 · Booking OTP confirmation dialog cancel is ineffective

`mobile/lib/features/provider/provider_active_job_cockpit_screen.dart:177`:

```dart
if (shouldContinue != true && !mounted) return;
```

The `&&` makes this condition **never true** when `shouldContinue == null` (the user cancelled) — `null != true` is `true`, and `!mounted` is `false` while still mounted. So **both branches proceed**: dismissing the dialog still continues to job completion, bypassing the "Skip Photos / Add Photos" choice. Should be `||`.

### GAP-04 · P1 · Shadowed route: photo moderation is unreachable

`backend/src/ratings/ratings-admin.controller.ts` declares, in order:

```
:22   @Patch(':id/moderation')
:42   @Patch('photos/:photoId/moderation')
```

Both are three-segment paths. Express matches in declaration order, so a request to `/api/v1/admin/reviews/photos/<uuid>/moderation` binds `photos` → `:id`, routing it into the **review** moderation handler. The photo moderation endpoint returns `NotFoundException('Review not found')` (404) instead of moderating the photo. Declaring the literal segment first fixes it.

### GAP-05 · P1 · `/trust` has no access control at all

`admin/src/app/trust/page.tsx:37` calls `getSession()` and nothing else — **no code-level role check**. The navigation filter (`admin-shell.tsx:13`) is a convenience, not a control, exactly as the repository's own e2e test states at `e2e/tests/admin-operations.spec.ts:133-156`. That test is committed as `test.fixme` (`:148`), so the gap is known and pinned but unresolved. A `support_agent` can type the URL and read the trust-signal moderation queue. The backend still enforces `trustSignalsRead`, so the exposure is read-only.

**6 of 18 admin routes have no code-level role check**: `/bookings`, `/providers`, `/support`, `/guarantees`, `/guarantees/[id]`, `/services` — plus `/trust` with no check at all.

### GAP-06 · P1 · Nav grants `/support` to `auditor`, backend does not

`admin-shell.tsx:11` lists `auditor` in the `/support` nav roles. `permission-policies.ts:465-471` excludes `auditor` from `adminComplaintsRead`. An auditor therefore sees the Complaints & Escrow link and receives **403 on every request** (redirected to `/unauthorized`).

The same mismatch exists on `/services`: nav grants `auditor` (`:14`) and the backend grants it **read** access, but **not** create/update/delete (`:233-247`) — an auditor sees every form and gets a 403 on every submit.

### GAP-07 · P1 · Guarantee status `<select>` offers illegal transitions

`admin/src/app/guarantees/[id]/page.tsx:88-99` renders **all six** statuses with no transition table, unlike complaints which use `nextComplaintStatuses()` (`features/operations/complaint-lifecycle.ts:33`). An operator can submit `COMPLETED → PENDING` and receive a backend 409 rendered as a full-page `error.tsx`. This is the same class of defect the `check:body-dtos` / lifecycle work fixed for complaints.

### GAP-08 · P1 · Orphan migration shadows a real one

`backend/src/database/migrations/1789735751504-add-phone-to-users.ts` sits outside both discovery globs (`typeorm.config.ts:17`, `database.module.ts:20` — both resolve to `backend/migrations/`). It never runs. Its work is already performed by `1789748288429-AddPhoneColumnToUsers.ts`. Promoting it would fail `42701 duplicate_column` because its `ALTER TABLE "users" ADD "phone"` lacks `IF NOT EXISTS`.

### GAP-09 · P1 · Duplicate migration timestamp

`1786521300000` is used by **both** `BookingLineItems.ts` and `ComplaintsSchema.ts`. TypeORM keys on the `name` string, so both execute and both are recorded; their relative ordering is decided by glob sort rather than intent.

### GAP-10 · P1 · `auth_audit_events` cascades on user deletion

`1789749980000-RestoreBookingIntegrity.ts:93-94` restores the FK as `ON DELETE CASCADE` where the original (preserved in `1789749968260`'s `down()`) was `SET NULL`. Deleting a user therefore **erases their authentication audit trail**. The inverse drift also exists: `complaints.submitter` moved `CASCADE → SET NULL` (`:147-148`), so complaints now outlive their submitter. `verify-schema.ts` asserts constraint **existence** only, never `onDelete`, so neither drift is caught by any gate.

### GAP-11 · P1 · Complaint state machine is unenforced at the database

The full lifecycle lives in `shared/complaint-lifecycle.types.ts:27-57` as application code. There is **no DB constraint or trigger** on `complaints.status`. Any direct SQL `UPDATE` bypasses every rule. By contrast `booking_events` **is** protected by an immutability trigger (`1786519799533:74`) — the project applies this control inconsistently.

### GAP-12 · P1 · Chat message `clientMessageId` is not unique

`backend/src/bookings/domain/booking-message.entity.ts:30-36` declares `client_message_id varchar(64)` as nullable with **no unique index**. The field exists to enable idempotent sends, but nothing enforces it — a retried `POST /bookings/:id/messages` **inserts a duplicate message**. Compare `payment_events`, where the equivalent replay guard *is* a unique index.

### GAP-13 · P1 · Unauthenticated inbox stub in a fail-closed codebase

`backend/src/notifications/inbox.controller.ts:6` declares `@Public()` and returns a hardcoded `{notifications: []}`. The controller is **not registered in any module**, so it is currently unreachable — but it is live source that would become an unauthenticated route the moment someone adds it to a module. It also duplicates the real inbox at `notifications/domain/inbox.controller.ts:21`. Should be deleted.

### GAP-14 · P1 · `PATCH /admin/complaints/:id/status` accepts an unvalidated body

`admin-management.controller.ts:52` uses an inline TypeScript type literal rather than a DTO class. `ValidationPipe({whitelist, forbidNonWhitelisted})` cannot strip unknown keys from a non-class type, so arbitrary extra properties reach the service. `check:body-dtos` passes because it only greps for `@Body() <ClassName>` declarations — the gate cannot see this shape. Six sibling admin endpoints use proper DTOs; this one is the outlier.

### GAP-15 · P2 · `booking_messages`, `booking_calls`, `recurring_schedules`, `guarantee_claims` have structural integrity holes

- `recurring_schedules` — **no foreign keys at all**; `customer_id` is an orphan column at both entity and DB level
- `guarantee_claims` — **no FKs, no indexes, no unique constraint**; `evidence_urls` uses TypeORM `simple-array` (comma-joined text) which **corrupts any URL containing a comma**
- `review_photo_moderation_events` — **no FKs**; `photo_id` and `actor_user_id` are unconstrained
- `payment_orders`, `payment_events`, `refunds` — **no FKs**; `payment_events` is an append-only audit table that cannot detect a deleted order
- `customer_addresses` — no unique constraint permitting only one `is_default` per user

---

## §B — Verified risks

### GAP-16 · P1 · Schema behaviour checks silently skip on an empty database

`schema:verify` was executed: **46 passed, 0 failed**, but it printed:

```
note: no users/service_categories seeded, skipping write checks
```

The three **behavioural** probes — orphan booking → `23503`, negative `total_amount_minor` → `23514`, latitude `999` → `23514` — are exactly the checks that prove constraints actually bite, and all three were skipped (`verify-schema.ts:232-235`). `verify-fresh-schema.ts` plants the required fixtures but drops and creates a database, so it was **not run** in this audit. **The green result is therefore weaker than it appears.**

### GAP-17 · P1 · Admin `UserDetail` type promises fields the API never returns

`admin/src/features/operations/types.ts:16` declares `UserDetail = {id, email, name, status, roles, createdAt, updatedAt}`. `backend/src/admin/admin-management.service.ts:150-156` returns only `{id, status, roles, createdAt, updatedAt}`. `support/[complaintId]/page.tsx:217-218, 236-237` render `submitter.name`, `submitter.email`, `target.name`, `target.email` — all four **render blank** on the case dossier, and TypeScript cannot catch it because the type is a local lie.

### GAP-18 · P1 · `/admin/analytics` is broader than the console admits

`admin/src/app/page.tsx:23-25` restricts the dashboard to `operations_administrator`/`auditor`. The backend endpoint requires only `adminBookingsRead` (`admin-analytics.controller.ts:11`), whose roles are four — including **`support_agent`** and `trust_safety_reviewer` (`permission-policies.ts:356-364`). A `support_agent` token calling the API directly receives full platform-wide metrics. `/analytics` repeats the same over-broad grant.

### GAP-19 · P1 · Job proof is simulated and never persisted

`mobile/lib/design_system/fix_job_proof_dialog.dart`:

- `:391-406` — a **"Simulate test photos"** button ships in production and inserts a hardcoded 1×1 transparent PNG as both before and after proof
- `:97-176` — **any** `pickImage` failure (permission denied, no camera) silently substitutes the same dummy PNG as valid proof
- `:273` — saves into `JobProofRepository.instance`, an **in-memory singleton** (`features/bookings/job_proof_service.dart:38`) that is **never uploaded to the backend**

A provider can complete a job with no real photographic evidence, and nothing about that evidence is auditable.

### GAP-20 · P1 · `/bookings` emergency count is a substring heuristic

`admin/src/app/bookings/page.tsx:26-28` computes `emergencyCount` by string-matching `"emergency"` against `serviceCategoryId` and `description`, then renders it in an operational alert banner (`:69-74`). This is not an API field; it will miscount any category whose description happens to contain the word.

Similarly, the per-status filter counts (`:52`) are computed **over the current 20-row page only** but presented beside a page-wide total (`:42`).

### GAP-21 · P2 · Guarantee page server actions bypass the standard error contract

`admin/src/app/guarantees/[id]/page.tsx:31,39` `throw new Error(...)` from inline `"use server"` actions. Every other action in the app redirects with `?result=failed` (`operations/actions.ts:24,28-30`, `trust/actions.ts:10,13`, `providers/actions.ts:13,23,25`). These two therefore render the **full-page `error.tsx`** instead of the inline `labels` map that is already wired and correct at `:24-27` — making the `?result=failed` path for guarantees unreachable.

### GAP-22 · P2 · Native `url_launcher` stub silently no-ops, then reports success

`mobile/lib/features/location/url_launcher_stub.dart:1-3` is an empty function used on **all native platforms**. `map_navigation_launcher.dart:51-59` calls it and then shows *"Opening directions to destination"* — so on a real device the user is told navigation started and **nothing happens**.

### GAP-23 · P2 · Seven admin pages fetch full unpaginated lists

| Page | Endpoint | Limiting |
| --- | --- | --- |
| `/support` | `GET /admin/complaints` | none |
| `/support/[complaintId]` | `GET /admin/complaints` | none — **re-fetched in full just to render the sidebar** |
| `/search` | `GET /admin/complaints` | none — full list then client-side `.filter()` |
| `/search` | `GET /guarantees/claims` | none — full list then client-side `.filter()` |
| `/trust` | `GET /admin/trust/signals` | none (backend hard `take: 100`) |
| `/services` | `GET /admin/service-categories` | none |
| `/guarantees` | `GET /guarantees/claims` | optional status only |

`/search` also issues **2–4 sequential `await`s** (`:33,37,41,43`) rather than `Promise.all`, so one slow endpoint serialises the whole search.

### GAP-24 · P2 · Provider jobs date strip filters nothing

`mobile/lib/features/provider/provider_jobs_screen.dart:391-494` renders a 7-day strip whose `onTap` (`:414`) only changes `_selectedDayIndex` (highlight styling). `currentJobs` is computed at `:64` — **before** the strip — and is never filtered by the selected day. The control looks interactive and does nothing.

### GAP-25 · P2 · `/bookings` pagination control is missing

`admin/src/app/bookings/page.tsx:79` reads `page.nextCursor` only to print *"More records available"*. There is no "Load More" control, unlike `/providers` and `/users`. The list is therefore capped at the first 20 records with no way to see more.

### GAP-26 · P2 · Nav active-state mismatches

`admin-shell.tsx:19` remaps only `"Bookings"` and `"Trust & Safety"`. Therefore:

- both provider pages pass `current="Provider KYC Verification"` while the nav label is `"Providers & KYC Verification"` → **never highlights**
- `/search` passes `current="Overview Dashboard"` → **the dashboard highlights while the user is on search**
- `/analytics`, `/users`, `/users/[userId]` pass labels that exist in no nav entry

### GAP-27 · P2 · `/bookings/[bookingId]` is unreachable from the bookings list

`admin/src/app/bookings/page.tsx:97` renders `<tr>` rows that are **not links**. The detail route is reachable only from `/guarantees/[id]` and `/search`.

### GAP-28 · P2 · Two duplicate placeholder panes occupy ~40% of two admin layouts

`providers/page.tsx:119-124` and `support/page.tsx:132-137` render permanent static "RIGHT PANE: Placeholder Dossier" blocks (`min-h-[500px]`) that can never change state. They are not functional panes — they are layout holes left from an unimplemented split view.

### GAP-29 · P3 · Mobile address model fabricates geography

`mobile/lib/features/location/saved_address.dart`:

- `:21-22` — `SavedAddress` defaults `city='Bengaluru'`, `postalCode='560034'`
- `:184-185` — fetch fallback silently substitutes `'560001'`
- `:182-183` — `flatBuilding` **and** `streetArea` are both set from `j['street']`
- `:148-150` — `setUserId()` is an **empty function**
- `:195-197, 252-254, 272-275` — all three network methods **swallow errors silently**
- `:121-129` — the singleton falls back to a `MockApiTransport` returning `200 []`
- `fix_address_selector.dart:469-470` — the new-address form **pre-fills** `'Bengaluru'`/`'560034'` into editable fields, so a user anywhere else starts with wrong data

### GAP-30 · P3 · Tracking screen shows the same stranger's avatar to every user

`mobile/lib/features/tracking/booking_tracking_screen.dart:140` and `:360` both use one hardcoded `lh3.googleusercontent.com` URL as the current user's `CircleAvatar.backgroundImage`. Two further hardcoded logo images at `:76` and `service_discovery_screen.dart:1532` bypass the `FixBrandMark` design-system component.

---

## §C — Potential risks (need targeted investigation)

### GAP-31 · P1 · `typeorm.config.ts` silently falls back to `.env.example`

`backend/typeorm.config.ts:9-11` loads `.env.example` when `DATABASE_URL` is absent. `migration:run` will therefore target whatever `.env.example` points at rather than failing fast — a plausible path to running migrations against the wrong database.

### GAP-32 · P1 · Unpinned third-party geocoding sends user coordinates off-platform

`mobile/lib/features/location/live_location_service.dart:73,105` calls `https://api.bigdatacloud.net/data/reverse-geocode-client` with the user's coordinates. No consent gate specific to this third party, no documented DPA, and it is not listed in `docs/ai/governance-and-evaluation-architecture.md` or the vendor register. Failures return `null` silently (`:157`) and fall back to fabricated strings `'Local Area'` (`:122`), `'Current Area'` (`:136`).

### GAP-33 · P1 · Admin session refresh cookie is a fixed 30 days with no server invalidation check

`admin/src/auth/session.ts:18-19` sets `maxAge = 30 × 24 × 60 × 60` as a hardcoded constant. There is no server-side revocation check on the refresh cookie at read time — `getSession()` validates only the access token (`:36-45`). A revoked staff session with a stale refresh cookie remains nominally present until expiry.

### GAP-34 · P2 · No CSRF token on any admin server action

All mutations use Next.js Server Actions, which rely on Origin/Referer checking only. Combined with `sameSite:"strict"` cookies the exposure is low, but there is no explicit defence-in-depth, and `admin/src/auth/actions.ts` has **no rate limiting of its own** beyond the backend's 5/min.

### GAP-35 · P2 · Review photo status column length drift

Entity declares `varchar(512)` (`review-photo.entity.ts`); the database column is `varchar(16)`. Inserting a longer value would be truncated by PostgreSQL while TypeORM believes it succeeded.

### GAP-36 · P2 · Four enum entity/DB type-name mismatches

`ComplaintStatus`, `ComplaintTargetRole`, `PushPlatform`, and `GuaranteeClaimStatus` omit `enumName` on the entity while the migrations created named DB types (e.g. `complaints_status_enum`, `guarantee_claims_status_enum`). TypeORM would generate different type names on a future `schema:sync`, and `verify-schema.ts` does not compare enum type names.

### GAP-37 · P2 · `admin/analytics` cache failure is swallowed

`AdminAnalyticsService` logs `Analytics cache read failed, computing fresh: Error: redis down` and continues. Correct behaviour, but the degraded path is only visible in logs — `/health/readiness` does flip a Redis key, so this is likely fine. Recorded for completeness.

### GAP-38 · P3 · OSM public tile servers with no rate control

Three mobile files hardcode `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (`service_location_picker_sheet.dart:140`, `provider_live_map.dart:493`, `service_discovery_screen.dart:1656`). ADR-0012 records the decision but no attribution/UA policy or caching strategy is implemented. Flutter itself prints the OSM usage warning at runtime.

### GAP-39 · P3 · Dead native MethodChannels

`mobile/android/.../MainActivity.kt:86-149` implements `com.fixnow.mobile/audio_tone` and `voice_stream`. **No Dart caller exists.** Dead native surface that will confuse future work.

---

## §D — Stubs and fabricated data shipped in the product

### GAP-40 · P1 · "Simulate test photos" button in production (§B GAP-19 above)

The clearest instance of test scaffolding reachable by a real user.

### GAP-41 · P1 · Checkout sheet simulates payment success

`fix_payment_checkout_sheet.dart:146` — when `onProcessPayment == null`, a 600 ms delay precedes a **"Payment Successful! / VERIFIED & PAID"** celebration (`:740, :789`). This simulation path ships in the release binary. It is currently unreachable in production because the caller is gated behind the dev-only `_canPayLocally` check, but the sheet itself has no guard — a future caller that omits the callback gets a fake receipt.

### GAP-42 · P1 · Invoice PDF carries a hardcoded GSTIN and two conflicting addresses

`mobile/lib/features/payments/fix_pdf_invoice_builder.dart:13-19` hardcodes:

- `companyGstin = '24AAACF1234F1Z5'` — a pattern-obvious placeholder, and a **tax-compliance defect**: a GSTIN rendered from a client constant
- `companyAddress = 'Level 4, Commerce House, SG Highway, Ahmedabad, Gujarat - 380054'`
- `verifyUrl = 'https://fixnow.app/verify/invoice'` — **no route serves this anywhere in the repo**, so a user scanning the printed QR gets a 404 on a statutory document
- `customerName` defaults to `'FixNow Customer'`, `serviceAddress` to `'Ahmedabad, Gujarat, India'`
- a hardcoded Ahmedabad jurisdiction clause

Meanwhile `invoice_screen.dart:283-299` shows **`'Bengaluru, Karnataka 560102'`** with the same GSTIN. **Two different company addresses in one invoice flow.**

### GAP-43 · P1 · Notification "clear all" never reaches the server

`notification_repository.dart:90-96` maintains a client-side `_deletedIds` set. There is **no backend delete endpoint** for notifications. Clearing all appears to work, then the items return on the next fetch or app restart.

### GAP-44 · P1 · Admin shell shows every operator the same fabricated identity

`admin/src/components/admin-shell.tsx`:

- `:114` — hardcoded `"Chief Dispatcher"` display name on **every authenticated page**. `AdminSession` (`auth/types.ts:13`) has no name field, so there is nothing real to render
- `:115` — `roles[0]?.replace('_',' ') || 'Superadmin'`. `'Superadmin'` is **not in `staffRoles`** (`types.ts:1-10`), so it is an unreachable role rendered for any session with an empty role list; `replace('_',' ')` also only fixes the first underscore (`security_administrator` → `security administrator`)
- `:122` — one hardcoded third-party avatar URL, allow-listed in `next.config.ts:5`, meaning the admin console makes a third-party request on **every page load**
- `:67` — a literal `"Configured"` badge next to `env.appEnvironment`, which defaults to `development` (`config/env.ts:7`). The console asserts "Configured" about an unconfigured environment

### GAP-45 · P2 · Five mobile controls collect input or claim a capability and do nothing

| Control | Location | Reality |
| --- | --- | --- |
| Referral code field ("Get ₹150 OFF") | `auth_screen.dart:785-813` | `_referral.text` never read; `register()` has no referral parameter (`:83-117`). **No referral backend exists.** |
| "Biometric Quick Login" switch | `verification_screen.dart:697-702` | Local bool `:33`, never read, never persisted; **no `local_auth` dependency** |
| 3 push-category switches | `push_settings_card.dart:261-278` | `setState` only — no API, no storage |
| "Request Instant Callback" | `customer_help_screen.dart:812-845` | Opens a dialog saying unavailable, despite a working `POST /support/complaints/:id/callback-request` endpoint existing |
| Payment Methods row + chevron | `customer_profile_screen.dart:410-465` | No `InkWell`/`GestureDetector`/`onTap` anywhere in the subtree |

### GAP-46 · P2 · `showFixBanner` renders a live no-op button

`design_system/fix_banner.dart:43` — `onPressed: onAction ?? () {}`. When an action **label** is supplied without a handler, the label renders as a button that does nothing. Triggered in production from `map_navigation_launcher.dart:58`.

### GAP-47 · P2 · `_showInvoiceModal` has no path to the invoice

`notification_center_screen.dart:786-859` — the notification sheet shows only a Close button. A notification about a paid invoice offers no way to open it.

### GAP-48 · P2 · Hardcoded business values in live UI copy

| Value | Location | Problem |
| --- | --- | --- |
| `'Balance: ₹250 available'` | `fix_payment_checkout_sheet.dart:592` | **Fabricated wallet balance** — no wallet backend exists |
| `_gstMinor => (_subtotalMinor * 0.18)` | `fix_payment_checkout_sheet.dart:122` | GST rate hardcoded client-side |
| `'₹99 technician dispatch fee'`, `'3 minutes'` | `booking_tracking_screen.dart:1030,1038` | Policy embedded in UI copy |
| `'100% refund… Zero fee prior to arrival'` | `cancellation_dialog.dart:77` | **Contradicts** the ₹99/3-minute rule above |
| `₹30000`/`₹50000` price-filter thresholds | `fix_universal_search_bar.dart:183,195`, `service_discovery_screen.dart:515,518` | Hardcoded in both chip labels and predicates |
| `'support@fixnow.com'` vs `'support@fixnow.app'` | `service_discovery_screen.dart:2051` vs `fix_pdf_invoice_builder.dart:18` | Two different support addresses |

### GAP-49 · P3 · Permanently disabled SSO button

`admin/src/auth/login-form.tsx:100-108` — a "Corporate SSO" button that is `disabled` with explanatory text. Honest dead UI, but it ships.

---

## §E — Dead code and unreachable screens

### GAP-50 · P1 · 22 mobile files unreachable from `main.dart`

Dead: `features/ai/ai_diagnostic_screen.dart`, `features/ai/ai_recommendation_screen.dart`, `features/bookings/booking_lifecycle_views.dart`, `features/bookings/job_proof_service.dart`, `features/tracking/booking_tracking_overview_screen.dart`, `features/support/complaint_detail_screen.dart`, `features/provider/provider_setup_screen.dart`, `auth/provider_onboarding_entry_screen.dart`, `design_system/fix_service_card_gallery.dart`, `design_system/fix_provider_card_gallery.dart`, the whole `features/call/` tree, plus assorted private helpers.

### GAP-51 · P1 · Entire in-app calling feature is unwired

`features/call/call_repository.dart:12` (`HttpCallRepository`) and `call_session.dart:32` (`CallSession`) are **never instantiated**. The backend supports the full call lifecycle (`booking_calls`, 15 service tests, 6 controller tests, realtime `call.*` frames) and the UI renders Call buttons — but **no client code drives it**. The feature is backend-complete and client-absent.

### GAP-52 · P2 · Two demo galleries ship static sample records

`fix_service_card_gallery.dart:77-113` and `fix_provider_card_gallery.dart:99-142` contain fabricated providers and services with invented ratings (`4.9`, `1284` reviews), prices (`₹149`, `₹299`, `₹499`), an OTP (`'7362'`), and ETAs. They have **no import path from production code**. `booking_lifecycle_views.dart:77-100` contains two complete fake providers (`'Amit Sharma' 4.8/126 reviews`, `'Rajesh Patel' 4.9/89 reviews`).

### GAP-53 · P2 · 33 unreferenced design-system widgets

Including `FixStarRatingBurst`, `FixSlideToConfirm`, `FixSosVortexButton`, `EtaProgressRing`, `FixAudioWaveform`, `Fix3DSpatialBeacon`, `FixJourneyProgressLine`, `FixInvoiceCard`, `FixOtpDisplay`, `FixAiPromptCard`, `FixImage`. They compile into the release binary and are imported only by their own tests.

### GAP-54 · P2 · Fully orphaned admin routes

`/analytics` and `/users` have **no link anywhere in the application** — not in the nav array, not in the header, not in any page. `/users/[userId]` is reachable only from the orphaned `/users` and from `guarantees/[id]/page.tsx:146`. `/search` is reachable only from the header form (`admin-shell.tsx:97`), not the nav.

### GAP-55 · P3 · `/unauthorized` performs no auth check

`admin/src/app/unauthorized/page.tsx:3` is a server component that renders a logout form with **no session validation**. Harmless (it discloses nothing), but it is a reachable page with no guard.

---

## §F — Missing features

| Gap | Detail |
| --- | --- |
| **GAP-56 · P1** | **Server-side notification delete.** No endpoint exists, so "clear all" is client-only (GAP-43). |
| **GAP-57 · P1** | **Admin pages for review and photo moderation.** Both endpoints exist (`FN-097`, `FN-098`) with **zero UI**. Moderated reviews and photos are unreachable to operators. |
| **GAP-58 · P1** | **Guarantee lifecycle transition table.** Unlike complaints, none exists client-side, so illegal transitions are submitted (GAP-07). |
| **GAP-59 · P2** | **Client for the calling feature.** Backend + realtime complete; no client wiring (GAP-51). |
| **GAP-60 · P2** | **Job-proof persistence.** `JobProofRepository` is an in-memory singleton never uploaded (GAP-19). |
| **GAP-61 · P2** | **Biometric re-auth.** A UI switch exists with no `local_auth` dependency (GAP-45). |
| **GAP-62 · P2** | **Push category preferences.** Three switches with no backend field or endpoint (GAP-45). |
| **GAP-63 · P2** | **Referral system.** A field advertising "₹150 OFF" with no backend, no DTO, no parameter (GAP-45). |
| **GAP-64 · P2** | **Complaint callback wiring.** The backend endpoint exists; the help screen shows an "unavailable" dialog instead (GAP-45). |
| **GAP-65 · P2** | **Server-authoritative invoice entity data.** GSTIN, company address, and verify URL are client constants with a mutual contradiction (GAP-42). |
| **GAP-66 · P2** | **Pagination on complaints, trust signals, and categories.** Seven admin pages fetch everything (GAP-23). |
| **GAP-67 · P3** | **`/bookings` "Load More".** `nextCursor` is read and discarded (GAP-25). |
| **GAP-68 · P3** | **Provider jobs date filtering.** The strip is cosmetic (GAP-24). |
| **GAP-69 · P3** | **`AuthStatus.offline` / `.failure` UI.** No dedicated screen; errors only surface inside `AuthScreen` (see INVENTORY §3.5). |
| **GAP-70 · P3** | **Brand fonts.** `pubspec.yaml:49-78` comments out Playfair Display + Inter because the `.ttf` files are uncommitted; `app_typography.dart` falls back to Georgia/Roboto. A documented deliberate state, not a defect. |

---

## §G — Duplicated and conflicting implementations

| Gap | Detail |
| --- | --- |
| **GAP-71 · P1** | **Complaint lifecycle defined twice.** `shared/complaint-lifecycle.types.ts:27-57` is the server source of truth; `admin/src/features/operations/complaint-lifecycle.ts:19-25` is a hand-copied admin twin. `complaint-lifecycle.test.ts` pins **only the admin copy**. Nothing asserts the tables agree — they can drift silently. |
| **GAP-72 · P1** | **`shortId()` copy-pasted into 10 admin files** (`users/page.tsx:10`, `users/[userId]/page.tsx:10`, `trust/page.tsx:10`, `support/page.tsx:10`, `support/[complaintId]/page.tsx:22`, `providers/page.tsx:10`, `providers/[applicationId]/page.tsx:11`, `bookings/[bookingId]/page.tsx:12`, `guarantees/page.tsx:10`, `guarantees/[id]/page.tsx:12`). `accountLabel()` duplicated in 2. |
| **GAP-73 · P1** | **Two independent `getUser` implementations** — `operations/api.ts:14` (returns `UserDetail`) and `users/api.ts:11` (returns `UserSummary`). Same endpoint, two conflicting types; `UserDetail` is the incorrect one (GAP-17). |
| **GAP-74 · P2** | **Two admin fetch wrappers** — `auth/api.ts:9-22` and `features/management-api.ts:6-25` have different error semantics (the former special-cases 204, the latter maps every throw to 503). |
| **GAP-75 · P2** | **Role arrays duplicated in 7 admin files**, already diverging: nav grants `auditor` `/trust`-adjacent access that `search/page.tsx:11-13` does not (GAP-06). |
| **GAP-76 · P2** | **Two rating renderers disagree.** `sub_service_catalog_screen.dart` and `service_discovery_screen.dart:2214-2258` both render category ratings with different honesty rules. The catalog one now matches, but the duplication invites regression — and the same cleanup was already applied and then missed once before. |
| **GAP-77 · P2** | **`_formatCompactCount` vs `_formatReviewCount`** — identical compact-count logic exists in `fix_service_card.dart:1201` and now `sub_service_catalog_screen.dart:1313`. Two copies that must agree. |
| **GAP-78 · P2** | **Two `inbox.controller.ts` files** for notifications — the real one (`domain/`) and the dead `@Public()` stub (GAP-13). |
| **GAP-79 · P3** | **`StatusBadge` label map duplicated** in `features/status-badge.tsx:1-5` and inline per-page maps in `trust/page.tsx`, `bookings/[bookingId]/page.tsx`, `providers/[applicationId]/page.tsx`, `support/[complaintId]/page.tsx`. |
| **GAP-80 · P3** | **Three "guarantee journey" strings** disagree: PDF says Ahmedabad, invoice screen says Bengaluru, `saved_address.dart` defaults to Bengaluru (GAP-42). |

---

## §H — Untested and unverified surface

### GAP-81 · P1 · 85 backend integration tests unexecuted here

The isolated PostgreSQL on port **55432** is not running, so `npm run test:integration` (14 specs, 85 tests) could not run. These are the tests that prove **real constraint, transaction, and locking** behaviour — precisely the properties a unit test with mocked repositories cannot establish. The unit suite (894 tests) passes but mocks `DataSource`; it does not prove referential integrity.

### GAP-82 · P1 · Zero tests for the transactional outbox

`backend/src/outbox/outbox.service.ts` is 14,257 bytes with **no spec**. The outbox is the backbone of dispatch fan-out, expiry sweeping, reminders, and emergency waves. Its backlog gauge is asserted indirectly (`metrics.integration-spec:110-118`) but its claim/lease/retry/dedupe logic is untested.

### GAP-83 · P1 · Zero tests for storage and malware scanning

`src/storage/**` — `clamav-malware-scanner.ts` (fail-closed scanner), `s3-private-object-storage.ts`, `malware-scanner.ts`, `private-object-storage.ts` — **no tests at all**. KYC document safety rests entirely on this untested code.

### GAP-84 · P2 · Eleven controllers have no test

All three payments controllers, `provider-application.controller.ts` (the KYC queue the whole admin app drives), `provider-profile.controller.ts`, `provider-availability.controller.ts`, `provider-document.controller.ts`, `provider-verification.controller.ts`, `ratings.controller.ts`, `ratings-admin.controller.ts`, both trust controllers, `schedules.controller.ts`, `emergency.controller.ts`.

### GAP-85 · P2 · Notable services with no spec

`admin/admin-operations.service.ts` (behind all category/bookings/complaints admin endpoints), `bookings/booking-dispatch.handlers.ts` (9,156 B), `realtime/booking-projection.service.ts` (7,113 B), `health/system-health.service.ts` (10,901 B), `ai/providers/huggingface-ai.provider.ts` (8,578 B), `ai/providers/deterministic-ai.provider.ts` (11,290 B — the provider that powers **every** AI test), `services/sub-services.controller.ts` (the sub-service feature is entirely untested backend-side), `common/authorization/resource-ownership.ts` (8,031 B).

### GAP-86 · P2 · Shared contracts have no tests

All 17 `shared/*.types.ts` files. Because the backend imports `booking-lifecycle.types.ts` directly, a careless edit to the transition table is caught only by the integration suite — which did not run (GAP-81).

### GAP-87 · P2 · 12 of 18 admin routes have no test

Untested: `/`, `/analytics`, `/bookings`, `/bookings/[bookingId]`, `/guarantees`, `/guarantees/[id]`, `/login`, `/search`, `/services`, `/unauthorized`, `/users`, `/users/[userId]`, `/providers/[applicationId]`, the document proxy `route.ts`. No test exists for `management-api.ts` or any `api.ts`/`actions.ts` module.

### GAP-88 · P2 · Playwright journeys unexecuted

13 tests across 2 specs were not run (browsers not installed). One is a committed `test.fixme` documenting GAP-05.

### GAP-89 · P3 · Tests that assert mock behaviour rather than production behaviour

- `mobile/test/fix_tests.dart` is a **codemod script that rewrites `_test.dart` files** and lives in the test directory — running it mutates source
- `mobile/lib/features/location/saved_address.dart:4` ships a `MockApiTransport` inside production `lib/`
- `mobile/test/` fixtures inject fabricated ratings/prices to satisfy assertions; several were the source of the fabricated-data defects in §D
- The `StubApi` in `e2e/support/stub-api.ts` 404s everything it does not explicitly stub, so a newly added admin endpoint will appear to "work" in e2e only if the test is updated

---

## Priority ranking — what to fix first

| Rank | Gap | Why |
| --- | --- | --- |
| 1 | **GAP-01** | CI is red. One-line allowlist annotation; blocks all other merges. |
| 2 | **GAP-02** | `seed.js` destroys catalog data on every deploy. Data loss in production. |
| 3 | **GAP-19** | Job proof is fake, bypassable, and never persisted. Trust-integrity failure. |
| 4 | **GAP-03** | Cancel-guard logic bug lets job completion proceed against user intent. |
| 5 | **GAP-04** | Photo moderation endpoint is unreachable via its own route. |
| 6 | **GAP-05 / GAP-06** | Admin authorization gaps — nav treated as a control. |
| 7 | **GAP-42** | Hardcoded GSTIN on statutory documents is a compliance defect. |
| 8 | **GAP-10 / GAP-11 / GAP-12** | Audit-trail and integrity erosion (cascade delete, unenforced state machine, non-unique idempotency key). |
| 9 | **GAP-08 / GAP-09** | Migration hygiene — orphan and duplicate timestamp will bite on the next from-scratch build. |
| 10 | **GAP-81 / GAP-82 / GAP-83** | Untested critical infrastructure (integration suite, outbox, storage). |
| 11 | **GAP-50 – GAP-53** | Dead code ships in the binary and inflates the surface future work must reason about. |