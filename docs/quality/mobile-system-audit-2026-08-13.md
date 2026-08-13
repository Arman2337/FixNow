# Mobile and Local System Audit — 2026-08-13

## Outcome

FN-074 validated the current customer mobile foundation against a live local
NestJS API, isolated PostgreSQL and Redis services, and a physical Android 16
device. The tested foundation is healthy after correcting three backend
validation/startup defects and the highest-impact Home-screen UX issues.

This audit does not claim that roadmap features are complete. Support, booking
creation, authentication UI, payments, administration, notifications, and
other pending `PROJECT_TASKS.md` work remain outside the implemented surface.

## Environment

- Flutter 3.38.9 / Dart 3.10.8
- Android 16 physical device (`A059`)
- Node.js 22.14.0 / npm 10.9.2
- PostgreSQL 16 disposable container on `127.0.0.1:55432`
- Redis 7 disposable container on `127.0.0.1:56379`
- Backend smoke-test port `3300` because local port `3000` was already occupied

All database records used for the device walkthrough were synthetic and stored
only in the disposable FixNow test database.

## What Works

| Area | Evidence | Result |
| --- | --- | --- |
| Mobile static analysis | `flutter analyze` | Pass, no issues |
| Mobile unit/widget tests | `flutter test` | Pass, 40 tests |
| Android build/install | `flutter run -d 00162358M004276` | Pass |
| Backend lint | ESLint without auto-fix | Pass |
| Backend unit tests | Jest | Pass, 44 suites / 197 tests |
| Database migrations | run → revert → run against isolated PostgreSQL | Pass |
| Backend integration tests | Jest with isolated PostgreSQL and Redis | Pass, 9 suites / 38 tests |
| Backend build | `npm run build` | Pass |
| Backend runtime | liveness, readiness, and active-category requests | Pass; database reports up |
| Home | live API categories, optional location, offline recovery | Pass |
| Bookings | honest empty state and tracking widget coverage | Pass for implemented scope |
| Profile | unauthenticated boundary and retry state | Pass for implemented scope |
| Navigation | Home, Bookings, Help, Profile | Pass |

## Fixed Findings

### F-001 — Location prompt dominated the first viewport

Impact: High. The prompt repeated the same explanation and pushed service
discovery down the screen.

Fix: Shortened consent/privacy copy, removed repetition, preserved the optional
browsing fallback, and retained an explicit 48px action.

### F-002 — Service discovery used a large repetitive card stack

Impact: High. Every category appeared as a separate oversized card with the
same toolbox icon, reducing scan speed and making the app feel unfinished.

Fix: Replaced the stack with one calm grouped list, compact accessible rows,
subdued descriptions, dividers, and recognizable category-specific icons.

### F-003 — Customer UI exposed internal project-management language

Impact: High. Help and older location copy referred to tracked task IDs/work.

Fix: Removed implementation language. Help now states its preview limitation
plainly and provides an immediate-danger fallback without pretending that an
unimplemented support channel exists.

### F-004 — Integration tests could touch another project's Redis

Impact: High. The test setup forced `localhost:6379` even when a dedicated test
instance was requested.

Fix: Added `TEST_REDIS_URL` support and documented isolated usage.

### F-005 — Service-category integration suite was unsafe and order-dependent

Impact: Critical. It used an unauthenticated hard-coded database URL, omitted
related entity metadata, and dropped the schema used by other suites.

Fix: Enforced the documented loopback test database, loaded complete metadata,
removed schema ownership, made cleanup foreign-key safe, and closed the Nest
testing module reliably.

### F-006 — Built backend could not start

Impact: Critical. TypeScript emits the monorepo entrypoint at
`dist/backend/src/main.js`, while npm scripts tried `dist/main`.

Fix: Aligned Nest start/watch/debug and production scripts with the emitted
entrypoint. Liveness and readiness then passed against the isolated database.

## Current UI Assessment

- Baseline design score: C
- Final design score: B
- Baseline AI-slop score: C
- Final AI-slop score: B
- Goodwill: 78/100 — healthy foundation, constrained by incomplete product flows

The final Home screen has clearer hierarchy, recognizable service scanning,
and materially more content above the fold. The application remains a
foundation rather than a complete consumer product; its calm token system,
navigation, status communication, and accessibility behavior are sound.

## Evidence

- [Home before](evidence/fixnow-home-current.png)
- [Home after](evidence/fixnow-home-after.png)
- [Bookings](evidence/fixnow-bookings-current.png)
- [Help before customer-safe copy](evidence/fixnow-help-current.png)
- [Help after](evidence/fixnow-help-after.png)
- [Profile](evidence/fixnow-profile-current.png)

## Deferred

- Help/support functionality is not implemented; tracked separately as FN-075.
- Booking creation, customer sign-in/registration UI, and active booking setup
  are not available in the current mobile foundation.
- Admin, payment, AI, notification, infrastructure, and release work remains in
  its existing pending tasks.
- The Android debug build logged a one-time skipped-frame warning during cold
  start. No sustained interaction jank was observed; release-mode profiling is
  appropriate when the product flows are complete.
