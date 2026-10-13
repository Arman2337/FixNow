# FixNow Agent Handoff — Design Unification, Phase 1 UX & Offline-First Cache (Current Session)

**Session date:** 2026-10-08
**Branch:** `fix/security-and-schema-integrity` (stay on this branch — do NOT create a new one)
**Git state:** NOTHING COMMITTED. Mobile and backend work both sit in the working tree. Review with `git diff` / `git status` before committing.

> **For the next agent:** read ONLY this file to resume. It covers this session's scope end to end: what is done, what is proven, what remains, and the traps that cost time here. Then read `AGENTS.md` and `PROJECT_TASKS.md` for repo rules and task IDs.

---

## 1. What this session was (one paragraph)

The product owner approved a single design direction — **light emerald/slate palette + Inter typography, bundled** — and a roadmap of UX upgrades. Five tasks were completed: **FN-138** (unify the design system), **FN-139** (live-booking island + one-tap rebook row), **FN-140** (offline-first bookings & discovery cache — the DESIGN.md §28 contract the app had inverted into a dead-end screen), **FN-141** (the accessibility harness DESIGN.md §31 asks for, plus the gate that makes it fail the build), and **FN-142** (the before/after job-proof backend pipeline, built because research found there was none — see §2). Interactive previews of the design work live in `design-preview/`.

## 2. DONE (verified)

### FN-138 — Design system unification
- **Inter bundled as an app asset.** `mobile/assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf` + `Inter-LICENSE.txt` (Inter 4.1, SIL OFL 1.1). Declared in `mobile/pubspec.yaml` under `fonts:` with weights 400/500/600/700.
- **Runtime font fetch removed.** `google_fonts` dependency deleted from `mobile/pubspec.yaml`; `app_typography.dart` rewritten to plain `TextStyle(fontFamily: kFixNowFontFamily)`. Token sizes/weights/line-heights preserved 1:1 (incl. legacy aliases).
- **Fake-dark theme bug fixed.** `AppTheme.dark` previously flipped only `Brightness` while keeping the light palette and setting `scaffoldBackgroundColor: AppColors.backgroundPrimary` (a near-white `#F8F9FF`) — so `themeMode: dark` rendered light by accident. Now there is ONE theme: `AppTheme.light` → private `_buildLightTheme()`; `trustMatrixTheme` and the `dark` getter are gone.
- **`app.dart`** uses `theme: AppTheme.light`, `themeMode: ThemeMode.light`.
- **85 test references** migrated `AppTheme.dark` → `AppTheme.light` across 25 test files; `app_test.dart` theme-mode expectation updated; the old "dark theme exposes the approved semantic colors" test rewritten as "the approved theme exposes the semantic colors" (asserts `Brightness.light`, canvas token, Inter family).
- **`DESIGN.md` reconciled**: §1, §4 (token table now matches `app_colors.dart`), §5 (Inter only), §33, §38, §40. Stale "cobalt/navy/Playfair/dark" doc comments cleaned in `fix_card.dart`, `fix_service_card.dart`, `fix_audio_waveform.dart`; `mobile/assets/fonts/README.md` rewritten.

### FN-139 — Live booking island + rebook row
- **`mobile/lib/design_system/fix_active_booking_island.dart` (new)** — slate pill above the bottom nav: service label, plain-language status (`fixActiveBookingStatusLabel`: `EN_ROUTE` → "On the way to you"), provider initial, optional ETA, chevron. Entrance = `AppMotion.container` (300ms, easeOutCubic), skipped entirely under `MediaQuery.disableAnimations`.
- **`mobile/lib/app/app_shell.dart`** — new `activeBookingIsland` slot between the page and the nav bar.
- **`mobile/lib/features/bookings/booking.dart`** — `kActiveBookingStatuses` + `CustomerBookingList.firstActive` extension ("is anything in flight" lives in the domain model, not widgets).
- **`mobile/lib/app/app.dart`** — `_ActiveBookingIslandSlot` (private, bottom of file) listens to `BookingController` **internally**, resolves the service label from live categories, and routes taps: customer → booking tracking/detail; provider → Active Job tab via `_providerShellController` (the app now owns one and disposes it).
- **`mobile/lib/features/services/rebook_row.dart` (new)** — `FixRebookRow`: up to 3 completed bookings, relative ages ("Completed 12 days ago"), Book-again CTA each. Renders NOTHING when no callback / no controller / no completed history.
- **`service_discovery_screen.dart`** — new `onBookAgain` callback; row sits between the emergency banner and Quick Services; wired in `app.dart` to the existing FN-108 `_openRebooking` flow.
- **16 new tests:** `fix_active_booking_island_test.dart`, `fix_rebook_row_test.dart`, `app_shell_island_test.dart`.

### FN-140 — Offline-first bookings & discovery cache
- **`mobile/lib/data/last_good_cache.dart` (new)** — `LastGoodCache` over a `SnapshotStore` interface. `MemorySnapshotStore` (tests, web) and `FileSnapshotStore` (app-private documents dir via `path_provider`; one JSON file, so `clear()` is a delete). Versioned envelope `{v, savedAt, data}`; `offlineSnapshotAgeLabel()`; `createDefaultSnapshotStore()`.
- **`mobile/lib/design_system/fix_saved_data_banner.dart` (new)** — `FixSavedDataBanner`: "Showing saved data" / "Updated 12m ago · may be out of date", live region, optional retry, semantic tokens only. Renders nothing when `savedAt` is null, so screens leave it in the tree unconditionally.
- **`booking.dart` / `service_category.dart`** — `toJson()` mirroring each model's own `fromJson` (no second schema for the cache to drift against).
- **`booking_controller.dart` / `service_discovery_controller.dart`** — optional `cache`; `isShowingSavedData` + `savedDataAt`. Writes on every live read (including the 5s realtime reconcile, create, cancel, reschedule); falls back to the snapshot on `offline`/`timeout` only. A 5xx, auth failure or unparseable body still surfaces as an error.
- **`customer_bookings_screen.dart` / `service_discovery_screen.dart`** — banner above the list.
- **`app.dart`** — one `LastGoodCache` scoped to `() => _auth.session?.userId`, injected into both controllers, `clear()`ed in `_signOut()`, and `_revalidateCachedData()` called on resume. `FixNowApp.snapshotStore` is injectable.
- **49 new tests:** `last_good_cache_test.dart` (20), `fix_saved_data_banner_test.dart` (7), `offline_first_bookings_test.dart` (12), `offline_first_discovery_test.dart` (10). `app_test.dart` now injects `MemorySnapshotStore`.

### FN-141 — Accessibility harness + build-failing gate
- **`mobile/test/support/accessibility_harness.dart` (new)** — the reusable harness: `wcagContrastRatio` / `expectMeetsWcagAa`, `pumpForAccessibility` (200% text, 320pt, reduced motion, settles), `expectRendersWithoutOverflow`, `expectActionsAreLabelled`, `expectMinimumTouchTargets`, `expectFocusOrder`, and `expectCheckFails` (the harness's own self-test helper).
- **`accessibilityCoverage`** in the same file maps every `lib/design_system/*.dart` component file to `audited()` or `deferred(reason)`. **Adding a component without classifying it fails the build.** The gate also rejects entries pointing at deleted files and deferred entries without a real reason.
- **`mobile/test/accessibility_harness_test.dart` (new, 59 tests)** — runs the harness against deliberately broken fixtures first (so a check that stopped looking cannot pass silently), then 13 real components at 200% text, then the token contrast contract, then the coverage gate.
- **Three real defects found and fixed:** `FixTextField` gave the field no accessible name (the label was plain `Text`, so a screen reader announced "text field" and stopped); `FixStaleDataBanner` overflowed by 10px at 200% text and clipped its own reconnect action (`Row` → `Wrap`); `fix_journey_progress_line.dart` was missing from the coverage map entirely.
- **De-duplication:** the WCAG formula that was copy-pasted into `design_system_test.dart`, `provider_core_test.dart` and `provider_active_job_cockpit_test.dart` is now one shared implementation.
- **Not claimed:** the harness renders through the widget tester, not a device. No real TalkBack/VoiceOver, platform focus rings, gesture navigation or OS text-scale clamp. That stays a manual release step and is written into the harness header.

### FN-142 — Before/after job proof backend pipeline (backend only; the mobile consumer is FN-143)
The roadmap item said this was a UI wiring job because `fix_before_after_slider.dart` and `fix_job_proof_dialog.dart` exist. **They were the only part that existed.** There was no backend entity, table, migration, route or DTO; the data source was the client-side in-memory `JobProofRepository`; and `booking_detail_screen.dart:525` already rendered a customer-facing proof card from that map — which can only ever be true inside the provider's own process, and vanishes on restart. Do not wire the mobile UI to `JobProofRepository`.
- **`backend/src/bookings/domain/job-proof-photo.entity.ts`** + **`migrations/1789750400000-JobProofPhotos.ts`** — `job_proof_photos`, one BEFORE and one AFTER per booking, named FKs, both unique indexes, two CHECKs, reversible.
- **`backend/src/bookings/job-proof-photos.service.ts`** — capture (assigned provider only; ASSIGNED/EN_ROUTE/IN_PROGRESS/COMPLETED only; magic-byte, size, malware scan before the row is written; sha256; same-stage re-capture replaces and deletes the old object), `listForParticipants`, `readPhoto` (scoped by booking **and** photo id), `present` (no `objectKey`, no `sha256`).
- **`backend/src/bookings/job-proof-photos.controller.ts`** — `POST/GET /bookings/:id/job-proof/photos` and `GET .../:photoId/content`, which streams bytes with `nosniff` + `no-store`.
- **Permissions:** `bookings.job-proof.create.self` (verified provider only — a customer must not author the proof) and `bookings.job-proof.read.booking` (customer + provider).
- **`scripts/verify-schema.ts`** — new FKs/CHECKs/indexes asserted, plus behavioural attempts proving PostgreSQL refuses an unknown stage, a zero-byte photo and a duplicate stage, and that BEFORE and AFTER can coexist.
- **18 new tests** in `job-proof-photos.service.spec.ts`. Backend: eslint clean, tsc clean, **107 suites / 912 tests**, production build, `check:body-dtos`, `check:env-declarations`, `deploy:verify-env` all pass. The schema gate needs live PostgreSQL and will run in the `schema` CI job; it was **not** executed here.

### FN-143 — Mobile job-proof surface (consumes FN-142)
- **`api_client.dart`** — new `BinaryDownloader` interface + `ApiClient.downloadFile` (authenticated, size-capped, refuses rather than truncating); `uploadFile` gained `fields` so the capture can send `stage`.
- **`booking_repository.dart`** — `jobProofPhotos` (reads the `{photos: [...]}` envelope), `jobProofBytes` (content endpoint, never a URL), `captureJobProof`.
- **`job_proof_controller.dart` (new)** — `JobProofStage`, `JobProofPhoto`, and states `initial/loading/ready/none/partial/error` + `missingSideLabel`.
- **`fix_job_proof_panel.dart` (new)** — the customer surface: nothing for `none`, slider for `ready`, **named** missing side for `partial`, error + retry for `error`.
- **`job_proof_service.dart`** — `JobProofRepository` **deleted**. Nothing references it.
- **`fix_job_proof_dialog.dart`** — `onUpload` is now **required**; each side uploads independently and a failure shows in place with the sheet kept open.
- **Wiring:** `booking_detail_screen.dart` takes `jobProofController`; provider screens reach it via `ProviderController.jobProof` rather than five new constructor params.
- `flutter analyze` no issues; `flutter test` **569/569**. The accessibility harness runs over `FixJobProofPanel` (200% text, 48px targets) and `FixBeforeAfterSlider` with real decoded bytes. `fix_job_proof_dialog.dart` is marked **deferred** with a written reason — it is a bottom sheet and the harness fixtures pump inline.

### Design previews (product-owner decision artifacts)
- `design-preview/index.html` — palette + type scale, before/after for every screen (rebuilt from code, NOT from screenshots), full motion playbook with interactive demos.
- `design-preview/index_1.html` — next upgrades: 16 UX items, the motion design language (12 named patterns + live easing/choreography/interruptibility demos), 8 backend power-ups, 4-phase sequencing.

## 3. How to verify (all green at handoff)

```bash
cd E:\FixNow\mobile
flutter pub get      # already resolved; google_fonts no longer present
flutter analyze      # -> "No issues found!"
flutter test         # -> 576/576 passing (mobile)
```

Baseline parity technique used here (worth reusing): create a throwaway worktree at HEAD (`git worktree add <path> HEAD --detach`), run the suite there, diff the failure lists, then `git worktree remove <path> --force`.

## 4. Files touched

**New:** `mobile/lib/data/last_good_cache.dart`, `mobile/lib/design_system/fix_active_booking_island.dart`, `mobile/lib/design_system/fix_saved_data_banner.dart`, `mobile/lib/features/services/rebook_row.dart`, `mobile/assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf`, `mobile/assets/fonts/Inter-LICENSE.txt`, `mobile/test/support/accessibility_harness.dart`, `mobile/test/{app_shell_island_test,accessibility_harness_test,fix_active_booking_island_test,fix_rebook_row_test,fix_saved_data_banner_test,last_good_cache_test,offline_first_bookings_test,offline_first_discovery_test}.dart`, `design-preview/{index.html,index_1.html}`

**Modified:** `DESIGN.md`, `PROJECT_TASKS.md`, `AGENT_HANDOFF.md`, `mobile/pubspec.yaml` (+ `.lock`), `mobile/assets/fonts/README.md`, `mobile/lib/app/{app.dart,app_shell.dart}`, `mobile/lib/design_system/{app_theme.dart,app_typography.dart,fix_card.dart,fix_components.dart,fix_service_card.dart,fix_state_views.dart,fix_audio_waveform.dart}`, `mobile/lib/features/bookings/{booking.dart,booking_controller.dart,customer_bookings_screen.dart}`, `mobile/lib/features/services/{service_category.dart,service_discovery_controller.dart,service_discovery_screen.dart}`, and 28 files under `mobile/test/` (25 mechanical `AppTheme.dark` → `AppTheme.light`, plus `app_test.dart`, `design_system_test.dart`, `provider_core_test.dart`, `provider_active_job_cockpit_test.dart`).

## 5. REMAINING (the approved roadmap — pick up here)

Full detail + previews live in `design-preview/index_1.html`. Sequencing:

### Phase 1 — finish the foundation
Phase 1 is **complete**: the offline-first cache (FN-140) and the accessibility harness (FN-141) both landed. The remaining roadmap starts at Phase 2.

### Known accessibility debt (recorded in `accessibilityCoverage`, not hidden)
`fix_journey_progress_line.dart` is `deferred` — its steps are individually tappable and need a full booking-journey fixture to assert step order. The 3D/motion primitives and the two card galleries are also deferred with written reasons in the harness. Turning `deferred` into `audited()` is the obvious next accessibility increment.

### Phase 2 — make trust visible
Phase 2 item 3 (before/after job proof) is **split**: FN-142 built the backend (done); FN-143 wires the app to it. Remaining:

4. Share-live-ETA signed deep link (new small public endpoint; tracking data already streams).
5. Chat polish: typing indicators, delivery/read ticks, quick canned replies (socket channel already open per booking).
6. Event-sourced booking timeline feeding customer "what happened" + admin audit.

### Also queued
Both closed:
- **FN-143** — mobile job-proof surface (consumer of FN-142; removed the `JobProofRepository` in-memory read).
- **FN-144** — the FN-110 review-photo contract mismatch.

### FN-144 — FN-110 review-photo contract (backend + mobile)
- `review-photos.service.ts` gained `readPhoto`, which resolves bytes **through the participant-visible set** rather than by bare id — the author may fetch their own pending/rejected photo, the other participant gets APPROVED only, so a guessed photo id cannot bypass moderation.
- `ratings.controller.ts` gained `GET /bookings/:id/review/photos/:photoId/content` (`inline`, `nosniff`, `no-store`).
- `booking_repository.dart` — `reviewPhotos` reads `{photos:[...]}` and now **throws on a wrong shape**; `reviewPhotoBytes` hits the content endpoint; `BookingRepository` takes an optional `BinaryDownloader`.
- `booking_review_panel.dart` renders a 72px thumbnail with a semantic label; a rejected photo is never fetched, so it cannot render as a broken image beside "not published after moderation".
- **The trap worth remembering:** `booking_review_test.dart`'s fake answered with a bare list **because the client did**. Both sides agreed on a shape neither had, so the test that should have caught the bug endorsed it — fixing the client alone failed the test, and the fake had to be corrected too.
- Backend: eslint/tsc/build clean, **107 suites / 918 tests** (6 new). Mobile: analyze clean, **576/576** (7 new).

### Phase 3 — marketplace intelligence
7. Fairness in matching scoring — the code comment in `backend/src/matching/matching.service.ts` already documents BUG-007 starvation ("the same nearest providers won every job"). Weighted rotation + fairness counter + starvation floor.
8. ETA as honest intervals: `{estimate, confidence, updatedAt}` (`backend/src/realtime/eta-adapter.ts`).
9. Demand heatmaps from location ingest → provider "go here" nudges.
10. Anti-fraud/trust signals (velocity, review authenticity, collusion) feeding the existing trust/verification queue.

### Phase 4 — scale & polish
11. AI diagnosis → prefilled booking (both screens exist).
12. Voice-first problem entry (`voice_assistance.dart`, `fix_audio_waveform.dart` exist).
13. Calibrated price estimates (P50/P90 bands with measured confidence).
14. Automated settlement/reconciliation behind the existing vendor-neutral gateway.
15. Matching precompute (zone candidate cache) + SLO dashboards + soak test.

## 6. Traps this session hit (read before editing)

1. **Never wrap the shell in a `ListenableBuilder`.** `AppShell` builds an `IndexedStack` of every destination, and `CustomerBookingsScreen.initState` calls `BookingController.load()` (which Notifies) during build. A listener *around* the shell becomes an ancestor marked dirty mid-build → "setState() or markNeedsBuild() called during build" and `app_test.dart` fails. Listeners that react to `BookingController` must live **inside a descendant** (that is why `_ActiveBookingIslandSlot` has its own `ListenableBuilder`).
2. **No horizontal `ListView` inside vertical scroll** — it demands unbounded height and crashes ("Horizontal viewport was given unbounded height"). Use `Wrap`.
3. **PowerShell 5.1 `Set-Content -Encoding UTF8` mangles UTF-8** (en-dashes → mojibake) and silently breaks 15 tests. For bulk file edits use `[System.IO.File]::ReadAllText/WriteAllText` with `New-Object System.Text.UTF8Encoding($false)`.
4. **`AppTheme.dark` no longer exists.** Do not reintroduce it; one light theme is the approved direction (owner-approved).
5. **`ThemeData` has no `fontFamily` getter** — assert the bundled family via `theme.textTheme.bodyMedium?.fontFamily`.
6. **Fixed-height cards clip at 200% text scale** — use `minHeight`/`ConstrainedBox`, and `Flexible` + `maxLines` for trailing row text.
7. **`AppColors` is the only color source.** Watch for near-miss names: `primaryEmerald`/`success` (there is no bare `emerald`).
8. When a test file is edited by script, re-run the affected tests immediately — encoding damage shows up as bizarre string-comparison failures.
9. **Never `await` storage work before `notifyListeners()`.** FN-140's first cut awaited the snapshot write, which meant a slow disk held live data off the screen — and broke `app_test.dart`, because `path_provider`'s real file I/O never completes under the widget tester's fake clock. Notify first; treat persistence as bookkeeping. This is also why `FixNowApp` takes an injectable `snapshotStore` and the suite passes `MemorySnapshotStore`.
10. **Every exit path of a `load()` must notify.** An early `return` on the saved-data path left the screen on its loading skeleton over data that had in fact arrived. Structure it as "notify on success, then `return`; notify once at the end for failures".
11. **Real async I/O needs a pure-Dart test file.** `flutter_test`'s fake clock will not advance `dart:io`, so file-store behaviour belongs in a test file with no `testWidgets` (that is where the `FileSnapshotStore` tests live).
12. `pumpAndSettle` times out on any screen with the design system's looping tickers. Use the `pump_idle.dart` helper (`import 'pump_idle.dart';`) for every widget test, and `scrollUntilVisible` for content below the fold.
13. **A Semantics node is not a widget.** `SemanticsNode.owner` is the `SemanticsOwner`, and `Element.parent` is not public — so the harness describes offenders by kind + rect and matches focus by ancestor *containment* (checked both ways, because a text field's focus node lives inside the field's subtree).
14. **Stop the semantics walk at the first actionable node.** Material builds a button as several nested nodes and the inner ones inherit the tap flag; descending reports the label's rect (32px of text at 200%) as the control and makes every sized button look undersized.
15. **`SemanticsData.hasFlag` and `.flags` are deprecated.** Use `getSemanticsData().flagsCollection.isButton`. Same for `PipelineOwner.semanticsOwner`, which is null in a widget test until semantics are pumped — reach the root by walking up from the first `Scaffold` instead.
16. **`expectLater` cannot wrap a check that pumps.** Both are guarded and the harness trips `Guarded function conflict`. Use `expectCheckFails` from the harness, which catches the `TestFailure` itself.

## 7. Project rules that still bind (from AGENTS.md / repo)

- Stay on the current branch; never commit to `main`; nothing is committed yet this session — commit only when the user asks.
- One task per agent run; read `AGENTS.md` + `PROJECT_TASKS.md` first; mark tasks In Progress; validate before completing.
- `DESIGN.md` is the design source of truth — it now matches the code; changing it again requires explicit owner approval (see §36 Design Change Protocol).
- Dynamic values flow Database → Backend → API → Repository/State → UI. No fake production data, no hardcoded dynamic values, no mock repositories powering production screens.
- Screens consume semantic tokens only — no raw hex in UI code.

## 8. Suggested skills for the next agent

- **`tdd` / `test-driven-development`** — for each remaining roadmap item, write the failing widget test first (the FN-139 tests are the pattern to copy).
- **`investigate` (gstack) or `diagnosing-bugs`** — before touching matching/fairness or ETA work in the backend.
- **`qa` / `browse` (gstack)** — runtime verification of new screens. NOTE: the gstack browse binary is not built in this environment and building it needs user approval; prefer `flutter test` + manual runs, or ask the user.
- **`writing-skills` / `writing-for-agents`** — if a durable workflow gets codified.
- **`code-review` / `requesting-code-review`** — before committing the accumulated diff.

## 9. If the owner says "continue"

Start with **Phase 2 item 4 — the share-live-ETA signed deep link**. Everything the tracker listed as queued is now done (FN-138 through FN-144), and the tracking data already streams, so this is a new small public endpoint plus a share action. Before writing it, note the constraint that bit twice on this branch: the deep link must be **signed and expiring**, and a public endpoint that takes a booking id without proving the share is an IDOR waiting to happen. Follow the FN-139 through FN-144 pattern: failing test first, then implement, then `flutter analyze` and `flutter test` (expect 576+ green), then backend eslint/tsc/jest/build, new task ID **FN-145**, then report. Run the accessibility harness over anything that adds a control. Do not commit unless asked.
