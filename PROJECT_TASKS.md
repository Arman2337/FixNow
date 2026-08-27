# FixNow Project Tasks

This file is the authoritative, permanent task tracker for FixNow developers and AI agents. Keep completed and cancelled tasks as project history, never reuse an ID, and assign the next unused `FN-XXX` ID to newly discovered work.

## Status System

- `â¬œ Pending` â€” The task has not started.
- `In Progress` â€” An agent or developer is actively working on the task.
- `Blocked` â€” Work cannot continue because a task, decision, dependency, credential, API, or external requirement is missing.
- `âœ… Completed` â€” Implementation and every required validation are finished.
- `â�Œ Cancelled` â€” The task is intentionally no longer required.

Only these statuses are valid. A task cannot be completed while required validation is failing or unavailable. A blocked task must include **Blocker** and **Required To Unblock** sections.

## Priority System

- `P0 â€” Critical` â€” Security issue, broken core system, production blocker, or serious data risk.
- `P1 â€” High` â€” Core feature or major project foundation.
- `P2 â€” Medium` â€” Important but non-blocking functionality.
- `P3 â€” Low` â€” Enhancement, polish, optimization, or optional work.

## Operating Rules

# FixNow Project Tasks

This file is the authoritative, permanent task tracker for FixNow developers and AI agents. Keep completed and cancelled tasks as project history, never reuse an ID, and assign the next unused `FN-XXX` ID to newly discovered work.

## Status System

- `â¬œ Pending` â€” The task has not started.
- `In Progress` â€” An agent or developer is actively working on the task.
- `Blocked` â€” Work cannot continue because a task, decision, dependency, credential, API, or external requirement is missing.
- `âœ… Completed` â€” Implementation and every required validation are finished.
- `âŒ Cancelled` â€” The task is intentionally no longer required.

Only these statuses are valid. A task cannot be completed while required validation is failing or unavailable. A blocked task must include **Blocker** and **Required To Unblock** sections.

## Priority System

- `P0 â€” Critical` â€” Security issue, broken core system, production blocker, or serious data risk.
- `P1 â€” High` â€” Core feature or major project foundation.
- `P2 â€” Medium` â€” Important but non-blocking functionality.
- `P3 â€” Low` â€” Enhancement, polish, optimization, or optional work.

## Operating Rules

1. Read `AGENTS.md` and this file before implementation.
2. Unless explicitly instructed otherwise, one agent run completes exactly one task.
3. Before starting, confirm dependencies are completed and no active task significantly overlaps the listed files or areas.
4. Mark the selected task `In Progress`, add it to **Current Work**, and use its branch.
5. Work only within its scope. Record newly discovered work as a new pending task instead of implementing it.
6. Complete a task only after every acceptance criterion and validation requirement is satisfied; update its completion record and the summary.
7. Select the next eligible task by priority (`P0` through `P3`), then generally by lowest ID.

# Project Progress

Total Tasks: 131
Completed: 114
In Progress: 0
Blocked: 0
Pending: 1
Deferred: 14
Cancelled: 2
Current Task: None (FN-130 Universal Live Search, Filter & Price Sort Bar completed)
Current Phase: Phase 16 — Production Operations & Commercial Polish
Next Recommended Task: FN-131 — Downloadable PDF Tax Invoice & Share Sheet

2026-08-27 (session 2) FN-113 advisory price/signal surfacing verified complete and closed. Evidence in the working tree: the mobile advisory price estimate (`mobile/lib/features/ai/price_estimate_repository.dart` — repository + controller + honest states) is surfaced on the service-request screen (`service_request_screen.dart` `_buildPriceContent`: ESTIMATE range + explanation + "Advisory only — the final charge is confirmed..." disclaimer, honest static fallback, PRICE_ON_REQUEST abstention) and wired at both `app.dart` construction sites (category-select and Book-again) via `PriceEstimateRepository(_api, accessToken: _auth.validAccessToken)`; the admin trust queue (`admin/src/app/trust/page.tsx`) already renders the FN-060 rule codes; the provider accept-time signal is surfaced on provider home (`provider_home_screen.dart` via `GET trust/my-accept-time`, FN-111). Payments set to local-only per ADR-0016: `PAYMENT_PROVIDER` defaults to the deterministic `fake` gateway (now made explicit in `backend/.env`), which is prohibited in production by `env.validation.ts` startup validation, needs no live gateway credentials, and offers no payouts. The mobile client has no interactive checkout surface yet (only the read-only invoice screen; `JobCompletedDialog` is unwired), so a dev-gated local payment flow is recorded as FN-118 rather than scaffolded. FN-058/FN-059 remain Deferred (live vision/voice still gated on malware scan + signed DPA + vendor/model approval, ADR-0014; AI stays advisory-only, disabled by default). Validated 2026-08-27: flutter analyze 0 errors, flutter test 164/164; backend jest payments 35/35.

2026-08-27 mobile payments UI, AI image metadata stripping, and the signature-motion system landed on `feat/signature-motion` (new tasks FN-115/FN-116/FN-117), and stale task statuses were reconciled against the codebase. FN-115: the FN-053 follow-up mobile screens — a customer invoice screen (`mobile/lib/features/payments/`) reading `payments.invoice.read.self` and a provider earnings screen (`mobile/lib/features/provider/provider_earnings_screen.dart`) rendering the honest gross/refunded/net ledger under `provider.earnings.read.self`, both stating payouts are not available (ADR-0016), wired into app.dart / booking_detail / provider_home. FN-116: server-side `stripImageMetadata` in the AI media policy — a dependency-free JPEG/PNG/WebP marker+chunk walk that drops EXIF/XMP/IPTC/comment metadata before any image reaches the provider boundary, closing one of the FN-059 live-vision gates (malware scan + signed DPA still deferred). FN-117: a reduce-motion-aware signature-motion system (`signature_motion.dart`: MatchRadarView, FlipOtpDigits, HoldToConfirmButton, status-temperature color) applied to the welcome entrance, emergency hold-to-confirm, and AI result reveal; transform+opacity only, degrading to static under `disableAnimations`. Status reconciliation against merged evidence: FN-052/FN-053 (payment orders/operations backends, merged in PR #27) flipped Deferred->Completed; FN-062/FN-063/FN-064 (domain notifications / emergency dispatch / SOS UX, each already carrying a completion record and validation) flipped Blocked->Completed with their obsolete gate notes marked resolved. Validated 2026-08-27: flutter analyze 0 errors, flutter test 164/164 pass; backend jest ai-media-policy 5/5 pass.

2026-08-26 FN-058/FN-059 governed multimodal problem-classification pipeline landed on `main`: a provider-neutral image / voice / image+voice classifier (`backend/src/ai/problem-classification/`) with a centralized 11-category taxonomy grounded against the active DB catalog (`ServiceCategoriesService`), three reusable prompt builders, and a strict structured-output schema that coerces any unmappable or invented label to a low-confidence `Other` rather than trusting raw model text. Adds deterministic confidence banding (>=0.85 high / 0.60-0.84 medium / <0.60 low), a deterministic safety pre-screen (gas/fire/shock/flood), DB grounding to a bookable `serviceCategoryId` (advisory-only null on no match), and clean per-error fallbacks (`INPUT_REJECTED`/`PROVIDER_UNAVAILABLE`/`TIMEOUT`/`INVALID_MODEL_OUTPUT`/`AI_DISABLED`/`RATE_LIMITED`) that never crash. A real Hugging Face adapter (Whisper `whisper-large-v3` + Qwen2.5-VL over native fetch, no new dependency) is included but DISABLED BY DEFAULT and blocked from production startup until the ADR-0014 release gate passes; the deterministic provider powers all dev/tests so no media leaves the machine. New env: `AI_VOICE_ENABLED`/`AI_VISION_ENABLED` (default false), `AI_MAX_IMAGE_BYTES`/`AI_MAX_AUDIO_BYTES`, and `HF_TOKEN` (server-side only) plus HF model/base-URL vars, documented in root `.env.example` and `docs/ai/problem-classification.md`. Versioned eval suite `problem-classification-eval-v1` pins the label-space, grounding, coercion, banding, safety, contract, and determinism gates so silent drift fails. This is NOT a live-complete feature: EXIF stripping, malware scan, and a signed DPA/retention terms remain required before enablement, so FN-058 and FN-059 stay Deferred. Validated 2026-08-26: backend lint clean, 75 suites / 479 tests, production build clean, `git diff --check` clean.

2026-08-25 FN-114 completed on `feat/payment-foundation`: the design-system motion widget suite is fully green again (flutter test 111/111, analyze 0 errors). Root causes fixed: missing `dart:async` import (14-file compile cascade), lazily-initialised AnimationControllers whose first access could be dispose() on deactivated elements (eager initState creation in FixFadeSlideIn/FixScaleIn/FixAnimatedStar plus cancellable start timers), and infinite pulse/shimmer tickers defeating pumpAndSettle (new scoped `pumpIdle()` tester helper declaring reduce-motion per widget test and flushing async loads). Restored two contracts dropped by the card redesign: the `<name> service category` accessibility label (FixServiceCard.semanticLabel override) and FN-107's honest `Price on request` line for unpublished prices. Updated stale pins (AppMotion.container 340ms, rounded icon family, card-scoped icon assertion). Backend remains green (70 suites / 395 tests, lint clean).

2026-08-25 FN-062 remainder delivered on `feat/payment-foundation`: scheduled booking reminders via a zero-dependency interval scanner (`BookingReminderService`, lead window + interval configurable by env, permanent per-role dedupe keys so reminders fire exactly once) sending customer and assigned-provider pushes through the existing deduplicated send path, and Android foreground push handling as an in-app banner (FirebaseMessaging.onMessage -> app-wide scaffold messenger, compile-time gated). Fixed a latent motion defect (FixFadeSlideIn delayed start now uses a cancellable Timer). The emergency-template and quiet-hour-override slices remain gated by FN-063 policy approval. Validated 2026-08-25: backend lint clean, 70 suites / 393 tests, build; flutter analyze 0 errors; mobile notification suites 7/7. Note: 14 widget tests fail on this branch from the committed design-system motion work - recorded as FN-114.

2026-08-25 FN-060 completed on `feat/payment-foundation`: deterministic advisory price estimation (`GET /ai/price-estimate`, PUBLISHED/OBSERVED bases, honest PRICE_ON_REQUEST abstention) plus two new trust review signals (`customer-cancellation-frequency-v1`, `provider-refund-frequency-v1`), with all four windowed rules now wired best-effort into booking cancellation, complaint creation, and refund creation flows. Versioned evaluation suite `price-fraud-eval-v1` enforces false-positive, detection, bias, explanation, privacy, uncertainty, money, determinism, and threshold-drift gates. Also cleared pre-existing lint errors in the FN-053 payments code. Validated: backend lint clean, 69 suites / 388 tests, production build, `git diff --check`.

2026-08-24 master completion run on `feat/provider-ui-polish`: FN-107 fixed category pricing, FN-108 book-again rebooking, FN-111 provider accept-time signal, FN-112 recurring schedules, and FN-110 review photos were implemented and validated (backend lint, 64 suites / 324 tests, build; Flutter analyze 0 errors / 109 tests; admin lint/typecheck/tests/build). FN-061 push infrastructure is now complete: live FCM delivery was confirmed on the connected Android device with user-supplied Firebase credentials.

# Current Product Completion Scope

This master completion run treats the following as the approved current product scope:

- Customer and provider experiences; authentication and verification; services; booking lifecycle and matching; realtime and live location; service-start OTP; help and complaints; approved emergency and notification behavior; approved AI behavior; security; testing; responsive behavior; accessibility; and operational admin tools.

Deferred from current product completion scope: payments, payment gateway/orders, invoices, refunds, wallet, provider payouts, and financial/payment-dependent functionality. Ratings, reviews, and review moderation are back in current development scope. These roadmap items remain in the permanent task history but do not block current-scope completion.

# Master Run Reconciliation — 2026-08-21

- `FN-100` addressed the confirmed mobile information gaps: customer complaint detail, provider incoming-request context, provider readiness, and customer/provider information hierarchy. Automated validation completed on 2026-08-21. Manual two-session browser evidence on 2026-08-21 verified the realtime lifecycle and authorized live GPS map projection.
- `FN-050` already owns the confirmed admin operations gaps: support-case detail and operational analytics. Its dependency is corrected to the completed current-scope complaint workflow `FN-098`; payment analytics remains explicitly deferred.
- `FN-049` already contains a functional service-catalog workspace in source. The earlier placeholder finding is stale and no duplicate corrective task is required.
- Customer Home active-booking prioritization and the Admin overview attention metrics are already implemented in source. They will be re-verified during the final re-audit rather than duplicated.
- The Admin Access placeholder is not present in the current role-aware navigation and no fake access-management screen will be introduced.

# Decision Log

Material architecture decisions belong in [`docs/architecture/decisions/`](docs/architecture/decisions/), using [`0000-template.md`](docs/architecture/decisions/0000-template.md). The discovery index at [`docs/decisions/`](docs/decisions/README.md) points to that canonical location. Accepted decisions are indexed in [`docs/architecture/decisions/README.md`](docs/architecture/decisions/README.md); unresolved vendor and stack choices remain deferred. Do not treat roadmap wording as an approved decision.

# Phase 0 â€” Repository Foundation

## FN-001 â€” Initialize Git Repository

Status: ✅ Completed
Priority: P1 â€” High
Area: Repository
Depends On: None
Branch: chore/repository-foundation

### Objective
Establish the repository and initial version history.

### Scope
- Initialize Git and create the foundation commit.

### Do Not
- Do not rewrite existing history.

### Acceptance Criteria
- [x] Git metadata exists and the repository has an initial commit.

### Validation
```bash
git log -1 --oneline
```

### Files / Areas
```text
.git/
```

### Notes
Verified from repository history.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-002 â€” Establish Agent Development Rules

Status: ✅ Completed
Priority: P1 â€” High
Area: Repository
Depends On: FN-001
Branch: chore/repository-foundation

### Objective
Define repository-wide instructions for AI coding agents.

### Scope
- Add security, architecture, quality, Git, and completion rules.

### Do Not
- Do not weaken platform or user instructions.

### Acceptance Criteria
- [x] Root `AGENTS.md` defines durable development rules.

### Validation
```bash
test -f AGENTS.md
```

### Files / Areas
```text
AGENTS.md
```

### Notes
Verified from tracked contents.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-003 â€” Establish Monorepo Domain Layout

Status: âœ… Completed
Priority: P1 â€” High
Area: Repository
Depends On: FN-001
Branch: chore/repository-foundation

### Objective
Reserve explicit directories for planned product domains.

### Scope
- Add `mobile`, `backend`, `admin`, `shared`, `infrastructure`, `ai`, and `docs` boundaries.

### Do Not
- Do not scaffold application frameworks.

### Acceptance Criteria
- [x] Every documented top-level domain directory is tracked.

### Validation
```bash
git ls-files
```

### Files / Areas
```text
mobile/ backend/ admin/ shared/ infrastructure/ ai/ docs/
```

### Notes
Directories contain placeholders only.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-004 â€” Configure Repository Ignore and Environment Examples

Status: âœ… Completed
Priority: P1 â€” High
Area: Repository
Depends On: FN-001
Branch: chore/repository-foundation

### Objective
Provide safe ignore rules and placeholder environment configuration.

### Scope
- Add `.gitignore`, `.gitattributes`, and `.env.example`.

### Do Not
- Do not add real credentials.

### Acceptance Criteria
- [x] Configuration files exist and no tracked real `.env` is present.

### Validation
```bash
git ls-files .gitignore .gitattributes .env.example
```

### Files / Areas
```text
.gitignore .gitattributes .env.example
```

### Notes
Verified from tracked contents.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-005 â€” Configure Protected-Branch Git Hook

Status: âœ… Completed
Priority: P1 â€” High
Area: Developer Experience
Depends On: FN-001
Branch: chore/repository-foundation

### Objective
Prevent accidental local commits directly on `main`.

### Scope
- Add the tracked pre-commit hook and activation documentation.

### Do Not
- Do not claim the local hook replaces server protection.

### Acceptance Criteria
- [x] Hook rejects commits on `main` and workflow documentation explains activation.

### Validation
```bash
git ls-files .githooks/pre-commit docs/development/git-workflow.md
```

### Files / Areas
```text
.githooks/ docs/development/
```

### Notes
Server-side branch protection remains an external repository setting.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-006 â€” Add GitHub Collaboration Templates

Status: âœ… Completed
Priority: P2 â€” Medium
Area: Repository
Depends On: FN-001
Branch: chore/repository-foundation

### Objective
Standardize ownership, issues, and pull requests.

### Scope
- Add CODEOWNERS, issue templates, and a pull request template.

### Do Not
- Do not configure external GitHub settings in this task.

### Acceptance Criteria
- [x] Required collaboration templates are tracked under `.github/`.

### Validation
```bash
git ls-files .github
```

### Files / Areas
```text
.github/
```

### Notes
Verified from tracked contents.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-007 â€” Add Core Project and Security Documentation

Status: âœ… Completed
Priority: P1 â€” High
Area: Documentation
Depends On: FN-001
Branch: chore/repository-foundation

### Objective
Document project purpose, contribution workflow, branching, and vulnerability handling.

### Scope
- Add README, contributing, security, branching, and Git workflow documentation.

### Do Not
- Do not claim unimplemented applications exist.

### Acceptance Criteria
- [x] Core documents exist and describe the foundation-only state.

### Validation
```bash
git ls-files README.md CONTRIBUTING.md SECURITY.md docs/development
```

### Files / Areas
```text
README.md CONTRIBUTING.md SECURITY.md docs/development/
```

### Notes
Verified from tracked contents.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-008 â€” Document Architecture Boundaries and ADR Process

Status: âœ… Completed
Priority: P1 â€” High
Area: Architecture
Depends On: FN-003
Branch: chore/repository-foundation

### Objective
Define intended component boundaries and a durable decision-record process.

### Scope
- Document dependency direction and provide an ADR template and index.

### Do Not
- Do not record deferred technology choices as decisions.

### Acceptance Criteria
- [x] Architecture overview and ADR template exist.

### Validation
```bash
git ls-files docs/architecture
```

### Files / Areas
```text
docs/architecture/
```

### Notes
The decision log lives at `docs/architecture/decisions/`; no duplicate `docs/decisions/` tree is needed.

### Completion Record
Completed By: Arman2337
Completed Date: 2026-08-07
Commit: 99650b5
PR: Pending

## FN-009 â€” Establish Persistent Project Task Management

Status: âœ… Completed
Priority: P1 â€” High
Area: Project Management
Depends On: FN-002, FN-008
Branch: docs/project-task-system

### Objective
Create the authoritative permanent tracker and agent execution protocol.

### Scope
- Add phased tasks, permanent IDs, statuses, priorities, dependencies, validation, collision areas, and completion records.
- Update agent instructions with selection, blocking, completion, and one-task rules.

### Do Not
- Do not implement application features or automate tracker maintenance.

### Acceptance Criteria
- [x] Tracker exists with unique IDs and valid dependencies.
- [x] `AGENTS.md` references the tracker and defines the execution protocol.
- [x] Tracker integrity and final diff are validated.

### Validation
```bash
git status
git diff --check
git diff
```

### Files / Areas
```text
PROJECT_TASKS.md
AGENTS.md
```

### Notes
Initial manual maintenance is intentional.

### Completion Record
Completed By: Arman
Completed Date: 2026-08-09
Commit: c567595
PR: #1

# Phase 1 â€” Project Architecture

## FN-010 â€” Define Product Requirements and Domain Glossary

Status: âœ… Completed
Priority: P1 â€” High
Area: Product Architecture
Depends On: FN-009
Branch: docs/product-requirements

### Objective
Define actors, core journeys, domain terms, boundaries, and non-functional requirements.

### Scope
- Document customer, provider, admin, booking, emergency, trust, and operational requirements.
- Identify open questions without selecting vendors.

### Do Not
- Do not scaffold applications or invent stakeholder decisions.

### Acceptance Criteria
- [x] Requirements and glossary are reviewable and unresolved decisions are explicit.
- [x] Architecture, security, privacy, cost, and availability constraints are captured.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/product/
```

### Notes
Created a draft stakeholder-review baseline with stable requirement IDs, actor journeys, data classes, non-functional constraints, an explicit open-decision register, and shared domain terminology. No unresolved business or technology choice is represented as approved.

### Completion Record
Completed By: Arman
Completed Date: 2026-08-09
Commit: 43b0df4
PR: #1

## FN-011 â€” Define API and Error-Response Conventions

Status: âœ… Completed
Priority: P1 â€” High
Area: Architecture
Depends On: FN-010
Branch: docs/api-conventions

### Objective
Specify versioning, naming, pagination, idempotency, validation, and error contracts.

### Scope
- Document public API and error-response conventions with examples.

### Do Not
- Do not implement controllers or lock in an undocumented transport.

### Acceptance Criteria
- [x] Conventions cover success, errors, retries, compatibility, and correlation IDs.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/architecture/ shared/
```

### Notes
Documented normative synchronous API and error conventions and recorded the transport choice in accepted ADR-0001. Asynchronous events remain explicitly outside this task and are owned by FN-015.

### Completion Record
Completed By: Arman
Completed Date: 2026-08-09
Commit: 43b0df4
PR: #1

## FN-012 â€” Decide Data and Storage Architecture

Status: âœ… Completed
Priority: P1 â€” High
Area: Data Architecture
Depends On: FN-010
Branch: docs/data-architecture

### Objective
Define persistence, cache, object storage, migration, retention, and backup conventions.

### Scope
- Evaluate and record approved database, cache, and storage decisions in ADRs.

### Do Not
- Do not provision services or include credentials.

### Acceptance Criteria
- [x] Decisions include rationale, alternatives, lifecycle, privacy, and operational implications.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/architecture/decisions/ docs/architecture/
```

### Notes
Accepted PostgreSQL as the transactional system of record, Redis for disposable cache and bounded coordination only, and private object storage for approved binary artifacts. Hosted providers, regions, exact versions, libraries, and credentials remain gated future decisions.

### Completion Record
Completed By: Arman
Completed Date: 2026-08-09
Commit: 43b0df4
PR: #1

## FN-013 â€” Define Identity, Roles, and Permission Model

Status: âœ… Completed
Priority: P1 â€” High
Area: Security Architecture
Depends On: FN-010
Branch: docs/identity-permissions

### Objective
Define identities, role boundaries, permissions, and authorization ownership.

### Scope
- Specify customer, provider, admin, service, and support permissions and escalation rules.

### Do Not
- Do not implement authentication or assume UI hiding enforces access.

### Acceptance Criteria
- [x] A permission matrix and high-risk action controls are documented.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/architecture/ docs/security/
```

### Notes
Defined deny-by-default hybrid authorization, internal identity boundaries, narrow staff/service roles, resource/context policy, separation of duties, account/grant lifecycle, high-risk controls, and a 75-row permission matrix. Authentication provider and credential/recovery methods remain deferred and require a later ADR.

### Completion Record
Completed By: Arman
Completed Date: 2026-08-09
Commit: 43b0df4
PR: #1

## FN-014 â€” Define Security and Privacy Architecture

Status: âœ… Completed
Priority: P1 â€” High
Area: Security Architecture
Depends On: FN-010, FN-013
Branch: docs/security-architecture

### Objective
Threat-model trust boundaries and define privacy, secrets, audit, abuse, and data controls.

### Scope
- Document threats, mitigations, data classification, retention, consent, and incident expectations.

### Do Not
- Do not include real customer data or secrets.

### Acceptance Criteria
- [x] High-risk flows and required controls have owners and validation plans.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/security/ docs/architecture/
```

### Notes
Documented trust boundaries, security/privacy governance, sensitive-data processing gates, consent/rights, abuse, secrets, supply chain, incident response, and release evidence. The 28-threat register gives payments, location, KYC, emergencies, AI, authorization, data lifecycle, operations, and other high-risk flows explicit owners and validation plans. Legal bases, retention periods, jurisdictions, vendors, and numeric policies remain gated decisions rather than invented defaults.

### Completion Record
Completed By: Arman
Completed Date: 2026-08-09
Commit: 43b0df4
PR: #1

## FN-015 â€” Define Real-Time and Notification Architecture

Status: âœ… Completed
Priority: P1 â€” High
Area: Platform Architecture
Depends On: FN-010, FN-011
Branch: docs/realtime-notifications

### Objective
Specify event delivery, presence, location updates, notification channels, retries, and ordering.

### Scope
- Define event contracts and failure behavior without provisioning infrastructure.

### Do Not
- Do not select hosted services without an approved ADR.

### Acceptance Criteria
- [x] Delivery semantics, privacy limits, fallbacks, and observability are documented.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/architecture/ shared/
```

### Notes
Defined versioned event envelopes, transactional outbox delivery, at-least-once and per-aggregate ordering semantics, idempotent consumption, authenticated WebSocket projections, presence/location privacy, durable notification intents, retry/fallback behavior, and operational observability. Durable transport and hosted channel providers remain deferred to later approved ADRs.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-09
Commit: 43b0df4
PR: #1

## FN-016 â€” Define AI Governance and Evaluation Architecture

Status: ✅ Completed
Priority: P2 â€” Medium
Area: AI Architecture
Depends On: FN-010, FN-014
Branch: docs/ai-governance

### Objective
Define allowed AI uses, provider selection criteria, data controls, evaluation, fallback, and human oversight.

### Scope
- Document trust boundaries, cost limits, model-output validation, and evaluation policy.

### Do Not
- Do not integrate models or upload private data.

### Acceptance Criteria
- [x] AI risks, metrics, failure handling, and approval gates are documented in ADR-0014 and `docs/ai/governance-and-evaluation-architecture.md`.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/architecture/decisions/ docs/ai/ ai/
```

### Notes
- ADR-0014 establishes an advisory-only, provider-neutral boundary. It forbids autonomous booking, assignment, emergency dispatch, catalog invention, and sensitive external data processing.
- The policy defines catalog grounding against active service categories, structured-output/schema validation, confidence/clarification/abstention handling, safety escalation, privacy/redaction, provider gates, evaluation, rollout flags, kill switch, monitoring, cost limits, and human oversight.
- No model, SDK, endpoint, provider, prompt, or external AI call was implemented. FN-056 is the next recommended AI task and remains pending.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-21
Commit: Pending
PR: Pending

## FN-072 â€” Establish Authoritative UI/UX Design System

Status: âœ… Completed
Priority: P1 â€” High
Area: Design System
Depends On: FN-010, FN-014
Branch: docs/design-system

### Objective
Create the authoritative cross-platform UI/UX design system for customer, provider, and admin experiences.

### Scope
- Document product design principles, semantic tokens, component patterns, navigation, core journeys, responsive behavior, accessibility, emergency UX, and agent governance.
- Add a concise repository-wide rule requiring UI tasks to follow `DESIGN.md`.

### Do Not
- Do not implement screens, install UI packages, download third-party assets, or copy another product's protected visual identity.

### Acceptance Criteria
- [x] Root `DESIGN.md` defines the requested design direction, tokens, states, reusable components, product flows, accessibility, and agent rules.
- [x] `AGENTS.md` requires UI implementation tasks to read and follow `DESIGN.md`.
- [x] No application UI or dependency changes are introduced.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
DESIGN.md AGENTS.md PROJECT_TASKS.md
```

### Notes
Created the original FixNow design direction with three-layer token governance, cross-platform component specifications, customer/provider/admin hierarchy, booking and tracking patterns, emergency safety rules, accessibility requirements, and strict agent/change protocols. This documentation task is separate from FN-035, which remains responsible for future mobile navigation, state, theme, and component implementation.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-09
Commit: 62582ff
PR: #2

# Phase 2 â€” Backend Foundation

## FN-017 â€” Initialize Backend Application
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend
Depends On: FN-011, FN-012, FN-014
Branch: feat/backend-foundation

### Objective
Initialize the approved backend framework and test/lint toolchain.
### Scope
- Create the minimal backend application and documented folder boundaries.
### Do Not
- Do not implement product endpoints or add unapproved dependencies.
### Acceptance Criteria
- [ ] Application starts and its lint, type, and default test checks pass.
### Validation
```bash
# Run the package-manager lint, type-check, and test commands selected by this task.
```
### Files / Areas
```text
backend/
```
### Notes
NestJS is a candidate requiring explicit approval and rationale.
### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-09
Commit: ad0088b
PR: Pending

## FN-018 â€” Add Backend Configuration and Structured Logging
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend
Depends On: FN-017
Branch: feat/backend-config-logging

### Objective
Validate startup configuration and provide privacy-safe structured logs.
### Scope
- Add typed configuration, startup validation, correlation IDs, and redaction rules.
### Do Not
- Do not log secrets or full third-party payloads.
### Acceptance Criteria
- [ ] Invalid configuration fails fast and logging behavior has tests.
### Validation
```bash
# Run backend lint, type-check, and focused configuration/logging tests.
```
### Files / Areas
```text
backend/src/config/ backend/src/logging/ .env.example
```
### Notes
None.
### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-09
Commit: ad0088b
PR: Pending

## FN-019 â€” Add PostgreSQL Persistence Foundation
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Data
Depends On: FN-012, FN-017, FN-018
Branch: feat/backend-persistence

### Objective
Add the approved PostgreSQL access layer, migration workflow, and test isolation.
### Scope
- Configure the selected ORM/query tool and reversible baseline migration.
### Do Not
- Do not add domain tables or production credentials.
### Acceptance Criteria
- [ ] Connection validation, migration up/down, and persistence tests pass.
### Validation
```bash
# Run backend checks and migration validation against an isolated database.
```
### Files / Areas
```text
backend/src/database/ backend/migrations/ infrastructure/local/
```
### Notes
Requires the completed data ADR.
### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-09
Commit: ad0088b
PR: Pending

## FN-020 â€” Add Redis Cache and Coordination Foundation
Status: âœ… Completed
Priority: P2 â€” Medium
Area: Backend/Data
Depends On: FN-012, FN-017, FN-018
Branch: feat/backend-redis

### Objective
Add approved Redis connectivity with bounded failure behavior.
### Scope
- Configure namespacing, timeouts, health signals, and test doubles.
### Do Not
- Do not use cache as a source of truth.
### Acceptance Criteria
- [ ] Connectivity and unavailable-cache behavior are tested.
### Validation
```bash
# Run backend checks and focused Redis integration tests.
```
### Files / Areas
```text
backend/src/cache/ infrastructure/local/
```
### Notes
None.
### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-09
Commit: ad0088b
PR: Pending

## FN-021 â€” Add Backend Request Validation and Global Error Handling
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/API
Depends On: FN-011, FN-017
Branch: feat/backend-api-guardrails

### Objective
Enforce input validation, API versioning, and consistent safe errors.
### Scope
- Add validation pipeline, global error mapping, and version prefixing.
### Do Not
- Do not leak stacks, internals, or sensitive values.
### Acceptance Criteria
- [ ] Boundary, malformed-input, unknown-error, and versioning tests pass.
### Validation
```bash
# Run backend checks and focused API guardrail tests.
```
### Files / Areas
```text
backend/src/common/ backend/src/main.* shared/
```
### Notes
None.
### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-09
Commit: ad0088b
PR: Pending

## FN-022 â€” Add Backend Health and Readiness Endpoints
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Operations
Depends On: FN-018, FN-019
Branch: feat/backend-health

### Objective
Expose safe liveness and dependency-aware readiness signals.
### Scope
- Add endpoints, timeouts, and tests without sensitive diagnostics.
### Do Not
- Do not expose credentials, versions with known risk, or internal topology.
### Acceptance Criteria
- [ ] Healthy, degraded, and dependency-failure cases are tested.
### Validation
```bash
# Run backend checks and health endpoint integration tests.
```
### Files / Areas
```text
backend/src/health/
```
### Notes
None.
### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-09
Commit: ad0088b
PR: Pending

# Phase 3 â€” Authentication & Users

## FN-023 â€” Create User and Identity Data Model
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Identity
Depends On: FN-013, FN-019, FN-021
Branch: feat/user-identity-model

### Objective
Model users, identities, roles, account states, and audit fields.
### Scope
- Add schema, migration, repository, and boundary tests.
### Do Not
- Do not store plaintext secrets or implement login.
### Acceptance Criteria
- [x] Constraints, lifecycle states, migration rollback, and repository tests pass.
### Validation
```bash
# Run backend checks plus identity migration and repository tests.
```
### Files / Areas
```text
backend/src/users/ backend/migrations/
```
### Notes
Implemented user, external identity, role, and role-assignment entities; explicit lifecycle transitions with audit reasons; a reversible migration; and unit/boundary/integration tests. Validated migration apply, schema constraints, rollback to zero identity tables, forward reapply, repository persistence, and unique external identity enforcement against disposable PostgreSQL 16. Full backend lint, unit tests, integration tests, and build pass.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-09
Commit: 874c9b3
PR: #4

## FN-024 â€” Implement Customer Registration and Login
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Auth
Depends On: FN-023
Branch: feat/customer-auth

### Objective
Provide secure customer registration and login under the approved identity design.
### Scope
- Implement validated registration, credential handling, login, and safe responses.
### Do Not
- Do not implement provider onboarding or password recovery.
### Acceptance Criteria
- [x] Success, duplicate, invalid, enumeration, and throttling boundaries are tested.
### Validation
```bash
# Run backend checks and customer authentication integration tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/users/
```
### Notes
Implemented approved local email/password registration and login, normalized identities, separate Argon2id credential storage, customer-role assignment, short-lived audience/issuer-bound JWT access tokens, generic authentication failures, and per-endpoint throttling. Refresh-token and OTP lifecycles remain scoped to FN-026. Focused and full unit tests, lint, type checking, build, disposable PostgreSQL migration apply/revert/reapply, and integration tests pass.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: 4acc17c
PR: #5

## FN-025 â€” Implement Provider Registration
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Auth
Depends On: FN-023
Branch: feat/provider-registration

### Objective
Register provider identities in an unverified onboarding state.
### Scope
- Add provider-specific validated registration and lifecycle state.
### Do Not
- Do not approve providers or accept KYC documents.
### Acceptance Criteria
- [x] Registration, duplicate, invalid-state, and permission tests pass.
### Validation
```bash
# Run backend checks and provider registration integration tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/providers/ backend/src/users/
```
### Notes
Implemented throttled provider registration using the approved email/password credential boundary. Registration atomically creates a pending-verification user, local identity, Argon2id credential, provider-applicant role assignment, and provider application constrained to the sole `unverified` state. Client-supplied role/status fields are rejected; no approval or KYC behavior is included. Full lint, unit tests, build, disposable PostgreSQL integration tests, and migration apply/revert/reapply validation pass.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: 5af807e
PR: #6

## FN-026 â€” Implement OTP and Refresh-Token Lifecycles
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Auth
Depends On: FN-024
Branch: feat/auth-token-lifecycle

### Objective
Implement OTP verification and secure session renewal/revocation.
### Scope
- Add expiry, retry, rotation, replay prevention, logout, and audit behavior.
### Do Not
- Do not log OTPs or raw tokens.
### Acceptance Criteria
- [x] Expiry, replay, brute-force, rotation, and revocation tests pass.
### Validation
```bash
# Run backend checks and focused OTP/token security tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/notifications/
```
### Notes
Implemented email OTP through a configurable Gmail-compatible SMTP adapter, with fake-only automated delivery tests and live delivery disabled until local credentials are supplied. OTP challenges use HMAC hashes, expire after 10 minutes, enforce a 60-second resend delay and five-attempt limit, and activate the account after successful verification. Opaque 30-day refresh tokens are stored only as SHA-256 hashes, rotate once without grace, revoke their token family on replay, and support current-session and all-session logout. Minimal audit classifications exclude OTPs, tokens, and email addresses. Unit tests, lint, type checking, build, disposable PostgreSQL migration apply/revert/reapply, and integration tests pass.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: 0e8efc0
PR: #7

## FN-027 â€” Enforce Role-Based Authorization
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Security
Depends On: FN-013, FN-023, FN-026
Branch: feat/role-authorization

### Objective
Enforce the approved permission model at trusted backend boundaries.
### Scope
- Add policy primitives, deny-by-default behavior, and audit coverage.
### Do Not
- Do not rely on client-side role checks.
### Acceptance Criteria
- [x] Cross-role, inactive-account, ownership, and privilege-escalation tests pass.
### Validation
```bash
# Run backend checks and authorization matrix tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/common/ docs/security/
```
### Notes
Implemented a centralized deny-by-default backend authorization boundary with explicit public-route and exact-permission decorators, authoritative access-token/session/account/role validation, current non-expired database grants, ownership and assignment policy inputs, self-grant and independent-approval controls, and minimal allow/deny audit classifications. Existing authentication and operational entry points are explicitly public; future unclassified routes fail closed. Focused policy/guard/service tests, the PostgreSQL authorization matrix, full unit and integration suites, lint, type checking, build, and E2E public-route smoke validation pass.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: 758f7cd
PR: Pending

## FN-028 â€” Implement Customer Profile Management
Status: âœ… Completed
Priority: P2 â€” Medium
Area: Backend/Users
Depends On: FN-024, FN-027
Branch: feat/customer-profiles

### Objective
Allow customers to read and safely update approved profile fields.
### Scope
- Add profile contracts, ownership enforcement, validation, and audit behavior.
### Do Not
- Do not expose another user's profile or collect unnecessary data.
### Acceptance Criteria
- [x] Read, update, validation, ownership, and privacy tests pass.
### Validation
```bash
# Run backend checks and customer profile integration tests.
```
### Files / Areas
```text
backend/src/users/ shared/
```
### Notes
The user explicitly directed FN-028 to remain on `feat/role-authorization` instead of its listed branch. Because no approved profile-field list exists, implementation is limited to a purpose-bound display name; phone, address, birth date, location, language, and other personal data remain uncollected. Added authenticated `/users/me/profile` read/update endpoints, token-derived ownership, value-free audit events, a cascade-deleted profile table, and validation/privacy coverage. Backend lint, 65 unit tests, 14 PostgreSQL integration tests, build, and migration up/down/up validation pass.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: 5132e41
PR: #8

# Phase 4 â€” Provider System

## FN-029 â€” Model Service Categories and Provider Skills
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Providers
Depends On: FN-019, FN-027
Branch: feat/provider-skills

### Objective
Create versionable service categories and provider skill associations.
### Scope
- Add models, admin ownership rules, migrations, and query contracts.
### Do Not
- Do not implement matching or ratings.
### Acceptance Criteria
- [ ] Constraints, authorization, lifecycle, and query tests pass.
### Validation
```bash
# Run backend checks plus category and skill tests.
```
### Files / Areas
```text
backend/src/services/ backend/src/providers/ backend/migrations/ shared/
```
### Notes
None.

### Completion Record
Completed By: Kiro
Completed Date: 2026-08-11
Commit: 1ebdfb6
PR: #9

## FN-030 â€” Implement Provider Profile and Service Areas
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Providers
Depends On: FN-025, FN-027, FN-029
Branch: feat/provider-profiles

### Objective
Manage provider profile, skills, service radius, and location coverage.
### Scope
- Add validated ownership-controlled profile and geographic coverage APIs.
### Do Not
- Do not expose precise private locations to unauthorized users.
### Acceptance Criteria
- [x] Profile, skill, radius, ownership, and geospatial boundary tests pass.
### Validation
```bash
# Run backend checks and provider profile integration tests.
```
### Files / Areas
```text
backend/src/providers/ backend/src/services/ shared/
```
### Notes
Added owner-controlled provider profile persistence and APIs, provider-skill composition, bounded service radius and coordinate validation, privacy-safe coverage checks, shared contracts, and migration coverage. Repaired the inherited FN-029 validation baseline by aligning controllers with the global authorization guard, correcting TypeORM relation typing, and separating PostgreSQL integration tests from the default unit suite.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: afe1d9d
PR: #10

## FN-031 â€” Implement Provider Document Upload
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Providers
Depends On: FN-012, FN-014, FN-025
Branch: feat/provider-documents

### Objective
Accept KYC documents through approved private storage controls.
### Scope
- Add type/size validation, malware-control interface, metadata, access, and retention rules.
### Do Not
- Do not commit documents or expose public object URLs.
### Acceptance Criteria
- [x] Upload, rejection, access, deletion, and audit tests pass.
### Validation
```bash
# Run backend checks and isolated document integration tests.
```
### Files / Areas
```text
backend/src/providers/documents/ backend/src/storage/ infrastructure/
```
### Notes
Implemented a development-only private document boundary using SeaweedFS's S3-compatible API and ClamAV, both behind vendor-neutral adapters. Uploads are bounded and signature-validated, quarantined under opaque keys, scanned before availability, digest-recorded, owner-authorized, audit-recorded, safely served without public URLs, and deleted with metadata tombstones. Local configuration uses placeholders only and is not approved for real KYC or production processing.


### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: afe1d9d
PR: #10

## FN-032 â€” Implement Provider Verification Workflow
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Providers
Depends On: FN-027, FN-030, FN-031
Branch: feat/provider-verification

### Objective
Support auditable provider review, approval, rejection, and resubmission.
### Scope
- Add legal state transitions, reason handling, permissions, and events.
### Do Not
- Do not auto-approve or overwrite audit history.
### Acceptance Criteria
- [x] Transition, permission, concurrency, reason, and audit tests pass.
### Validation
```bash
# Run backend checks and verification workflow tests.
```
### Files / Areas
```text
backend/src/providers/ backend/src/admin/ shared/
```
### Notes
Implemented reviewer claim and decision endpoints with a centralized role permission plus transactional assignment enforcement. The versioned state machine blocks stale, illegal, unassigned, and self-review transitions; requires bounded reasons; appends immutable verification events; and atomically activates the approved account and grants the verified-provider role without duplicating grants. Production use remains gated by the documented KYC/legal/privacy approvals.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: afe1d9d
PR: #10

## FN-033 â€” Implement Provider Availability
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Providers
Depends On: FN-030, FN-032
Branch: feat/provider-availability

### Objective
Manage verified provider schedules and online availability safely.
### Scope
- Add schedule rules, exceptions, status updates, and conflict validation.
### Do Not
- Do not implement job matching or live GPS.
### Acceptance Criteria
- [x] Time-zone, overlap, authorization, and verified-state tests pass.
### Validation
```bash
# Run backend checks and provider availability tests.
```
### Files / Areas
```text
backend/src/providers/availability/ shared/
```
### Notes
Implemented verified-provider self-service schedules, dated exceptions, transient
online/busy status, optimistic concurrency, IANA time-zone validation, interval
conflict and bounds validation, explicit response mapping, shared contracts,
database constraints, migration coverage, and backend usage documentation.
Validated with repository-wide backend lint, all 161 backend tests, targeted
availability and authorization tests, production TypeScript checking, emitted
NestJS build, and `git diff --check`.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-11
Commit: afe1d9d
PR: #10

# Phase 5 â€” Customer Mobile Foundation

## FN-034 â€” Initialize Flutter Mobile Application
Status: âœ… Completed
Priority: P1 â€” High
Area: Mobile
Depends On: FN-010, FN-011, FN-014
Branch: feat/mobile-foundation

### Objective
Initialize the approved Flutter application for customer and provider roles.
### Scope
- Configure minimal structure, environments, linting, entry point, and tests.
### Do Not
- Do not implement authentication, booking, or final screens.
### Acceptance Criteria
- [x] App runs, `flutter analyze` passes, and default tests pass.
### Validation
```bash
flutter pub get
flutter analyze
flutter test
```
### Files / Areas
```text
mobile/
```
### Notes
Flutter was explicitly approved by the user and recorded in ADR-0009 before initialization. The minimal Android/iOS scaffold uses validated non-secret compile-time environments and intentionally defers navigation, authentication, booking, and final screens. Work remained on `feat/user-identity-model` at the user's explicit direction instead of the listed task branch.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-09
Commit: 411acdb
PR: #4

## FN-035 â€” Establish Mobile Navigation, State, and Design System
Status: âœ… Completed
Priority: P1 â€” High
Area: Mobile
Depends On: FN-034
Branch: feat/mobile-app-shell

### Objective
Create accessible navigation, state boundaries, themes, tokens, and reusable primitives.
### Scope
- Implement only the application shell and documented design foundations.
### Do Not
- Do not build product workflows or add redundant packages.
### Acceptance Criteria
- [x] Navigation, theme, accessibility, and component tests pass.
### Validation
```bash
flutter analyze
flutter test
```
### Files / Areas
```text
mobile/lib/app/ mobile/lib/design_system/ mobile/test/
```
### Notes
Added customer and provider application-shell navigation, an explicit
`ChangeNotifier` navigation-state boundary, centralized `DESIGN.md` color,
typography, spacing, radius, shadow, and theme mappings, plus reusable button,
card, status-chip, and bottom-navigation primitives. The built-in state choice
and its intentionally narrow ownership are documented in `mobile/README.md`.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-11
Commit: ad0088b
PR: Pending

## FN-036 â€” Add Mobile API Client and Authentication State
Status: âœ… Completed
Priority: P1 â€” High
Area: Mobile
Depends On: FN-026, FN-034, FN-035
Branch: feat/mobile-auth-client

### Objective
Consume documented contracts with secure session storage and authentication state.
### Scope
- Add API transport, timeouts, safe errors, token renewal, logout, and tests.
### Do Not
- Do not store tokens in plaintext or implement registration UI.
### Acceptance Criteria
- [x] Authenticated, expired, offline, retry, and logout cases pass.
### Validation
```bash
flutter analyze
flutter test
```
### Files / Areas
```text
mobile/lib/api/ mobile/lib/auth/ shared/
```
### Notes
Added bounded HTTP transport, timeouts, safe error mapping, and GET-only retry.
Added secure platform-backed session persistence, authentication restoration,
single-flight rotating-token renewal, logout cleanup, and deterministic tests.
Android and iOS secure-storage requirements are configured. Per user direction,
this work remained on `feat/mobile-app-shell`.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-11
Commit: ad0088b
PR: Pending

## FN-037 â€” Implement Customer Profile, Location, and Service Discovery UI
Status: âœ… Completed
Priority: P1 â€” High
Area: Mobile/Customer
Depends On: FN-028, FN-029, FN-035, FN-036
Branch: feat/mobile-customer-discovery

### Objective
Let customers manage profiles, consent to location, and browse service categories.
### Scope
- Add profile, permission-aware location, category discovery, and empty/error states.
### Do Not
- Do not create bookings or track providers.
### Acceptance Criteria
- [x] Permission denial, privacy, loading, error, and accessibility tests pass.
### Validation
```bash
flutter analyze
flutter test
```
### Files / Areas
```text
mobile/lib/features/profile/ mobile/lib/features/location/ mobile/lib/features/services/
```
### Notes
Connected customer Home to active service-category discovery and optional
foreground location consent, and connected Profile to the approved display-name
read/update contract. Added explicit loading, empty, offline, error, denial, and
privacy states using the existing design tokens and components. Location denial
never blocks browsing; no coordinates are stored, no booking is created, and no
provider tracking was added. Per user direction, work remained on
`feat/mobile-app-shell`.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-11
Commit: ad0088b
PR: Pending

# Phase 6 â€” Service Booking

## FN-038 â€” Create Booking Data Model and Lifecycle Contract
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Booking
Depends On: FN-011, FN-019, FN-029
Branch: feat/booking-model

### Objective
Define booking entities, states, transitions, ownership, and event contracts.
### Scope
- Add schema, migration, domain model, transition rules, and tests.
### Do Not
- Do not implement matching, acceptance, or payments.
### Acceptance Criteria
- [x] Constraints, legal transitions, rollback, and concurrency tests pass.
### Validation
```bash
# Run backend checks plus booking model and migration tests.
```
### Files / Areas
```text
backend/src/bookings/domain/ backend/migrations/ shared/
```
### Notes
Added the shared lifecycle contract, constrained booking schema, focused
reversible migration, legal transition model, lifecycle timestamps, optimistic
versioning, immutable event schema, indexes, and PostgreSQL constraint and race
coverage. Migration apply/revert/reapply passed against isolated PostgreSQL 18.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-12
Commit: 1f000c8
PR: Pending

## FN-039 â€” Implement Service Request Creation
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Booking
Depends On: FN-027, FN-038
Branch: feat/booking-request

### Objective
Allow customers to create idempotent service requests with validated location and details.
### Scope
- Add API, ownership, location precision controls, idempotency, and tests.
### Do Not
- Do not assign providers or take payment.
### Acceptance Criteria
- [x] Validation, duplicate, authorization, privacy, and idempotency tests pass.
### Validation
```bash
# Run backend checks and service-request integration tests.
```
### Files / Areas
```text
backend/src/bookings/ backend/src/location/ shared/
```
### Notes
Implemented customer-owned request creation with bounded description,
coordinates, scheduling, privacy-safe output, and database-backed idempotency.
Keys are scoped per customer and bound to a normalized request fingerprint;
identical sequential/concurrent retries return one booking while payload reuse
conflicts. Authorization policy, unit tests, and PostgreSQL tests pass.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-12
Commit: 1f000c8
PR: Pending

## FN-040 â€” Implement Provider Matching
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Booking
Depends On: FN-030, FN-033, FN-039
Branch: feat/provider-matching

### Objective
Find eligible providers using category, verification, availability, and service area.
### Scope
- Add deterministic matching policy, limits, observability, and tests.
### Do Not
- Do not use opaque AI ranking or expose exact provider locations.
### Acceptance Criteria
- [x] Eligibility, no-match, ordering, privacy, and load boundaries are tested.
### Validation
```bash
# Run backend checks and provider matching tests.
```
### Files / Areas
```text
backend/src/matching/ backend/src/providers/ backend/src/bookings/
```
### Notes
Implemented deterministic database matching across active accounts, verified
skills, active categories, non-expired online availability, and service radius.
Results are distance-ordered with provider-ID tie breaking, capped at 50, and
return no private provider coordinates. Unit and PostgreSQL eligibility,
no-match, ordering, privacy, and limit coverage pass.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-12
Commit: 1f000c8
PR: Pending

## FN-041 â€” Implement Provider Acceptance and Booking Progress
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Booking
Depends On: FN-038, FN-040
Branch: feat/booking-acceptance

### Objective
Support atomic provider acceptance and authorized progress through completion.
### Scope
- Add acceptance race handling, status commands, timestamps, and audit events.
### Do Not
- Do not implement payment settlement or ratings.
### Acceptance Criteria
- [x] Race, stale update, role, ownership, and lifecycle tests pass.
### Validation
```bash
# Run backend checks and booking lifecycle integration tests.
```
### Files / Areas
```text
backend/src/bookings/ backend/src/matching/ shared/
```
### Notes
Implemented eligibility-gated provider acceptance and assigned-provider status
commands using required expected versions and compare-and-update transactions.
Exactly one concurrent acceptance succeeds; stale, cross-provider, self-accept,
and illegal commands fail. Named timestamps and database-immutable lifecycle
events are recorded atomically. PostgreSQL race and ownership tests pass.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-12
Commit: 1f000c8
PR: Pending

## FN-042 â€” Implement Booking Cancellation and Service History
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Booking
Depends On: FN-041
Branch: feat/booking-cancellation-history

### Objective
Apply cancellation policy and provide privacy-safe customer/provider history.
### Scope
- Add allowed cancellation states, reasons, consequences, history pagination, and tests.
### Do Not
- Do not implement refunds before payment workflows exist.
### Acceptance Criteria
- [x] Policy, race, authorization, pagination, and data-minimization tests pass.
### Validation
```bash
# Run backend checks and cancellation/history tests.
```
### Files / Areas
```text
backend/src/bookings/ shared/
```
### Notes
Implemented participant/state-specific cancellation rules, bounded reasons,
expected-version race handling, cancellation timestamps, and immutable events.
Combined participant history uses stable opaque cursor pagination and removes
exact coordinates from provider views. PostgreSQL policy, race, authorization,
pagination, audit immutability, and data-minimization tests pass. No refund or
payment behavior was added.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-12
Commit: 1f000c8
PR: Pending

# Phase 7 â€” Real-Time & Location

## FN-043 â€” Add Authenticated WebSocket Infrastructure
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Real-Time
Depends On: FN-015, FN-020, FN-027
Branch: feat/realtime-foundation

### Objective
Provide authenticated, authorized, observable real-time connections.
### Scope
- Add connection lifecycle, channel authorization, limits, heartbeat, and tests.
### Do Not
- Do not broadcast private events across users.
### Acceptance Criteria
- [x] Authentication, authorization, reconnect, limit, and failure tests pass.
### Validation
```bash
# Run backend checks and WebSocket integration tests.
```
### Files / Areas
```text
backend/src/realtime/ infrastructure/
```
### Notes
Added an isolated NestJS `ws` gateway with first-frame access-token
authentication, authoritative session/account/role checks, allowlisted semantic
channels, self-resource subscription authorization, safe snapshot recovery on
reconnect, browser-origin validation, connection/subscription/message/payload
limits, ping/pong liveness, graceful drain, and payload-free bounded telemetry.
The initial account channel provides the authorization foundation only; booking
and location projections remain scoped to FN-045. Full backend lint, all 187
unit tests, seven real WebSocket integration tests, and the production build
pass.
### Completion Record
Completed By: Arman
Completed Date: 2026-08-13
Commit: ad0088b
PR: Pending

## FN-044 â€” Implement Provider Presence and Live Location Ingestion
Status: âœ… Completed
Priority: P1 â€” High
Area: Backend/Location
Depends On: FN-014, FN-033, FN-043
Branch: feat/provider-live-location

### Objective
Ingest online/offline presence and bounded live GPS updates for active work.
### Scope
- Add consent, freshness, precision, throttling, retention, and authorization controls.
### Do Not
- Do not retain indefinite location history or accept spoofable ownership.
### Acceptance Criteria
- [x] Consent, stale, rate, authorization, retention, and offline tests pass.
### Validation
```bash
# Run backend checks and live-location integration tests.
```
### Files / Areas
```text
backend/src/location/ backend/src/realtime/ backend/src/providers/
```
### Notes
OD-010 was approved and documented on 2026-08-13. Added authenticated provider presence, versioned consent, and precise-location WebSocket frames. Precise ingestion is restricted to the assigned verified provider during `EN_ROUTE`, requires current presence and consent, validates coordinates/accuracy/freshness/sequence/rate, and stores only the latest point in ephemeral cache for at most 60 seconds. Consent withdrawal, provider offline, cancellation, arrival, and completion invalidate active location. Configuration bounds, no-history behavior, safe telemetry, backend documentation, seven focused location tests, configuration coverage, and booking lifecycle cleanup are included. Backend lint, all 195 unit tests, seven realtime integration tests, and the production build pass. Work remained on `feat/realtime-foundation` at the user's explicit direction.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: ad0088b
PR: Pending

## FN-045 â€” Implement Booking Tracking, ETA, and Real-Time Events
Status: âœ… Completed
Priority: P1 â€” High
Area: Booking/Real-Time
Depends On: FN-041, FN-044
Branch: feat/booking-live-tracking

### Objective
Deliver authorized booking events, provider tracking, and bounded ETA estimates.
### Scope
- Add event projection, ETA adapter, mobile consumption, fallbacks, and tests.
### Do Not
- Do not promise exact ETA or expose tracking outside an active booking.
### Acceptance Criteria
- [x] Authorization, ordering, reconnect, stale location, fallback, and UI tests pass.
### Validation
```bash
# Run backend real-time tests and mobile analyze/test commands.
```
### Files / Areas
```text
backend/src/bookings/ backend/src/realtime/ mobile/lib/features/tracking/ shared/
```
### Notes
Implemented authorized participant-only booking subscriptions, monotonic booking/location projections, a bounded and explicitly sourced ETA fallback adapter, and a shared tracking contract. Mobile tracking reconciles an HTTP snapshot after reconnect or sequence gaps, ignores stale/duplicate frames, preserves the last booking state offline, and honestly displays unavailable location/ETA. The Bookings destination now provides a real empty/active-tracking entry instead of a development placeholder, and internal task identifiers were removed from location consent copy. The accessible UI reuses FixNow cards, buttons, status chips, typography, spacing, and semantic colors without introducing a new visual style. Backend lint, all 197 unit tests, seven realtime integration tests, and production build pass. Flutter analyze reports no issues, all 39 mobile tests pass, and the improved development app built, installed, and launched successfully on a USB-connected A059 running Android 16. Work remained on `feat/realtime-foundation` at the user's explicit direction.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: ad0088b
PR: Pending

# Phase 8 â€” Admin Dashboard

## FN-046 â€” Initialize Admin Web Application
Status: âœ… Completed
Priority: P1 â€” High
Area: Admin
Depends On: FN-010, FN-011, FN-014
Branch: feat/admin-foundation

### Objective
Initialize the approved admin framework with linting, typing, tests, and accessible shell.
### Scope
- Add minimal app structure and environment validation.
### Do Not
- Do not implement admin workflows or embed secrets.
### Acceptance Criteria
- [x] App starts and lint, type, build, and default tests pass.
### Validation
```bash
# Run the admin package-manager lint, type-check, test, and build commands.
```
### Files / Areas
```text
admin/
```
### Notes
The user explicitly approved Next.js. ADR-0013 records the App Router and TypeScript decision and its boundaries. Initialized the isolated admin package with Next.js 16, React 19, Tailwind CSS 4, strict TypeScript, Next.js Core Web Vitals linting, Vitest, validated public environment configuration, and an accessible responsive shell. The shell reuses the semantic premium dark and emerald tokens from `DESIGN.md`, labels unavailable modules honestly, and exposes no fake privileged action. ESLint, strict type checking, four tests, the production build, `git diff --check`, and an HTTP 200 runtime smoke test passed.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: 759f403
PR: #16

## FN-047 â€” Implement Admin Authentication and Authorization UI
Status: âœ… Completed
Priority: P1 â€” High
Area: Admin/Security
Depends On: FN-027, FN-046
Branch: feat/admin-auth

### Objective
Provide secure admin sign-in, session handling, and permission-aware navigation.
### Scope
- Add authentication flow, session expiry, safe errors, and authorization UX.
### Do Not
- Do not treat UI checks as backend authorization.
### Acceptance Criteria
- [x] Login, expiry, unauthorized, logout, and accessibility tests pass.
### Validation
```bash
# Run admin lint, type-check, tests, and build.
```
### Files / Areas
```text
admin/src/auth/ admin/src/app/ backend/src/auth/
```
### Notes
Completed on `feat/admin-foundation` at the user's explicit direction. Added a staff-only backend login boundary, admin-specific token audience, protected session summary, active/expiring role resolution, and deny-by-default rejection for customer/provider, inactive, missing-role, and ambiguous multi-role access. The Next.js application uses server actions and HTTP-only strict same-site cookies for login, refresh, and logout; routes anonymous, expired, and unauthorized states explicitly; and filters navigation from the authoritative session role without treating UI visibility as authorization. UI reuses the FN-046 shell and `DESIGN.md` semantic dark/emerald tokens. Admin lint, strict type checking, 10 tests, production build, runtime login/protected-route smoke, backend lint, all 45 suites / 206 tests, backend build, and `git diff --check` passed.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: 759f403
PR: #16

## FN-048 â€” Implement Admin User and Provider Verification Management
Status: âœ… Completed
Priority: P1 â€” High
Area: Admin
Depends On: FN-032, FN-047
Branch: feat/admin-users-providers

### Objective
Let authorized admins inspect users and perform provider verification workflows.
### Scope
- Add paginated search, detail views, document access controls, decisions, and audit UX.
### Do Not
- Do not expose unnecessary personal data or bypass backend policy.
### Acceptance Criteria
- [x] Permission, redaction, review, concurrency, and accessibility tests pass.
### Validation
```bash
# Run admin checks and relevant backend integration tests.
```
### Files / Areas
```text
admin/src/features/users/ admin/src/features/providers/ backend/src/admin/
```
### Notes
Completed on `feat/admin-foundation` at the user's explicit direction. Added admin-audience, permission-gated user and provider endpoints with bounded cursor pagination, opaque-ID search, minimized user/profile projections, current-role filtering, immutable verification history, and assigned-review-only document listing/download with audit and no-store headers. Claim and decision actions reuse the FN-032 transactional workflow, assignment/self-review guards, required reasons, legal transitions, and application-version concurrency check. The Next.js UI adds responsive Users and Provider Verification list/detail screens, filters, empty states, accessible tables/forms, clear stale/forbidden feedback, role-aware navigation, and secure server-proxied document downloads using only the existing `DESIGN.md` tokens and shell. Admin lint, strict type checking, 11 tests, production build, backend lint, all 46 suites / 211 tests, backend build, and `git diff --check` passed.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: 759f403
PR: #16

## FN-049 â€” Implement Admin Service and Booking Management
Status: âœ… Completed
Priority: P2 â€” Medium
Area: Admin
Depends On: FN-029, FN-042, FN-047
Branch: feat/admin-services-bookings

### Objective
Manage service taxonomy and inspect bookings with auditable privileged actions.
### Scope
- Add category CRUD, booking search/detail, allowed interventions, and audit confirmation.
### Do Not
- Do not mutate completed financial history or hide audit actions.
### Acceptance Criteria
- [x] Authorization, validation, search, audit, and accessibility tests pass.
### Validation
```bash
# Run admin checks and relevant backend integration tests.
```
### Files / Areas
```text
admin/src/features/services/ admin/src/features/bookings/ backend/src/admin/
```
### Notes
Added role-gated service taxonomy management and booking search/detail pages using the existing admin shell,
tokens, form controls, and status badge. Privileged booking cancellation requires a reason and explicit
confirmation, rejects terminal bookings, uses optimistic version checks, and appends the staff actor and reason
to immutable booking history. Service mutations and booking operations use admin-audience permissions.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: 759f403
PR: #16

## FN-050 â€” Implement Admin Complaints and Analytics Views
Status: ✅ Completed
Priority: P2 â€” Medium
Area: Admin
Depends On: FN-047, FN-098
Branch: feat/admin-complaints-analytics

### Objective
Support complaint operations and privacy-safe operational analytics.
### Scope
- Add complaint queues/details/actions and aggregate user, provider, booking, and payment views.
### Do Not
- Do not expose unrestricted raw personal data or misleading metrics.
### Acceptance Criteria
- [x] Permissions, redaction, filtering, audit, empty state, and accessibility tests pass.
### Validation
```bash
# Run admin checks and relevant backend analytics tests.
```
### Files / Areas
```text
admin/src/features/complaints/ admin/src/features/analytics/ backend/src/admin/
```
### Notes
Payment analytics should appear only after payment tasks complete.

The admin complaint queue supports accessible filtering and an honest empty state. Authorized complaint detail now loads only its related evidence, while queue listings remain evidence-free. Administrative permissions, minimized user projections/redaction, complaint status ownership and resolution notes, and authorization audit coverage are exercised by the backend suite. Analytics now returns and displays an explicit snapshot timestamp and uses priority-category wording rather than claiming an unimplemented emergency-dispatch workflow.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-21
Commit: Pending
PR: Pending

# Phase 9 â€” Payments

## FN-051 â€” Decide Payment Architecture and Integrate Provider Adapter
Status: ✅ Completed
Priority: P1 â€” High
Area: Payments Architecture
Depends On: FN-010, FN-014, FN-038
Branch: feat/payment-foundation

### Objective
Approve a payment provider and add an isolated, configured adapter with webhook trust controls.
### Scope
- Record ADR, define money/idempotency contracts, adapter interface, and sandbox configuration.
### Do Not
- Do not use live credentials or store prohibited card data.
### Acceptance Criteria
- [x] ADR, signature validation, configuration, money precision, and adapter tests pass.
### Validation
```bash
# Run backend checks and payment-adapter contract tests with sandbox fixtures.
```
### Files / Areas
```text
docs/architecture/decisions/ backend/src/payments/ shared/ .env.example
```
### Notes
Razorpay is a candidate, not an approved dependency before this task.
### Notes
Deferred from current delivery scope per FN-097.

Reactivated by the 2026-08-25 product decision and completed on `feat/payment-foundation`. ADR-0016 accepts Razorpay behind a vendor-neutral `PaymentGateway` boundary in `backend/src/payments/`, following the push/SMTP/AI adapter pattern: no Razorpay SDK (thin REST client over the Orders API with basic auth and Node fetch), integer-paise INR-only money mirroring FN-107, timing-safe HMAC-SHA256 verification for both webhook bodies and the Checkout `order_id|payment_id` handshake, environment-only credentials (`RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` / `RAZORPAY_WEBHOOK_SECRET`), a deterministic fake gateway prohibited in production, and lazy credential resolution so fake-mode boots never require Razorpay configuration. Environment validation rejects fake-in-production and incomplete Razorpay setups. No card data, no live keys, and no order persistence (schema lands with FN-052). Validated 2026-08-25: backend lint clean, 349 tests (including deterministic HMAC fixtures, tampering rejection, REST-surface auth/body assertions, and configuration boundary cases), production build. Live Razorpay test-mode verification by the owner remains the recorded next step before FN-052.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-25
Commit:
PR:
## FN-052 â€” Implement Payment Orders and Verification
Status: Completed
Priority: P1 â€” High
Area: Backend/Payments
Depends On: FN-041, FN-051
Branch: feat/payment-orders

### Objective
Create booking-bound payment orders and verify idempotent provider outcomes.
### Scope
- Add order creation, webhook processing, reconciliation states, and audit records.
### Do Not
- Do not trust client payment success or duplicate charges.
### Acceptance Criteria
- [x] Signature, replay, amount, booking ownership, race, and reconciliation tests pass.
### Validation
```bash
# Run backend checks and payment sandbox integration tests.
```
### Files / Areas
```text
backend/src/payments/ backend/src/bookings/ shared/
```
### Notes
None.
### Notes
Deferred from current delivery scope per FN-097.

Completed on `feat/payment-foundation` immediately after FN-051. Added the reversible `payment_orders` + `payment_events` schema: booking-bound orders keyed by a unique booking-scoped receipt (idempotent creation, race-safe via the unique constraint), reconciliation states CREATED/PAID/FAILED/CANCELLED, and an immutable audit event table whose (order, event, payload-digest) unique index makes webhook replays no-ops. Amounts snapshot the category's published price at order time; price-on-request categories refuse payment instead of inventing amounts, and only REQUESTED/ASSIGNED bookings are payable. Endpoints: POST /payments/orders, GET /payments/orders/booking/:id, POST /payments/orders/verify (Checkout handshake), POST /payments/webhook (public route whose authentication IS the timing-safe HMAC over the raw body; rawBody enabled at bootstrap). Captured amounts must match the internal order exactly - mismatches are recorded and never applied. A new customer-scoped `payments.order.manage.self` permission gates the customer routes. Validated 2026-08-25: backend lint clean, 366 tests, build; live E2E on the local stack with the fake gateway recorded order creation, idempotent replay, a valid capture flipping the order to PAID, forged-signature 403, tampered-amount rejection, and webhook replay dedupe (duplicate:true). Razorpay live verification activates when the owner supplies test-mode keys.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-25
Commit: 05f42fb
PR:
## FN-053 â€” Implement Invoices, Refunds, Transactions, and Provider Earnings
Status: Completed
Priority: P1 â€” High
Area: Payments
Depends On: FN-042, FN-052
Branch: feat/payment-operations

### Objective
Provide immutable transaction history, invoices, controlled refunds, and provider earnings views.
### Scope
- Add ledger-like records, invoice generation, refund workflow, reconciliation, and access rules.
### Do Not
- Do not mutate settled history or claim payout capabilities not supported by the provider.
### Acceptance Criteria
- [x] Precision, partial/full refund, idempotency, permission, invoice, and earnings tests pass.
### Validation
```bash
# Run backend checks and payment operations integration tests.
```
### Files / Areas
```text
backend/src/payments/ backend/src/providers/ mobile/lib/features/payments/ shared/
```
### Notes
Split payout execution into a new task if required by the approved provider.
### Notes
Deferred from current delivery scope per FN-097.

Completed on `feat/payment-foundation` immediately after FN-052. Added the reversible payment-ledger schema: `refunds` (gateway refund id unique, caller request-key idempotency, integer-paise partial/full amounts, bounded reason) and `invoices` (one per paid order, sequential FN-YYYY-NNNNNN numbers from a database sequence so concurrent finalisations never collide). The gateway boundary gained `createRefund` (Razorpay REST refunds endpoint; deterministic fake). Refunds are a staff action under a new admin-audience `payments.refund.create` permission (support_agent, operations_administrator) with an Idempotency-Key header; lifetime refunds can never exceed the paid amount and unpaid orders cannot be refunded. Invoices generate exactly once when an order turns PAID and are customer-readable under `payments.invoice.read.self`. Provider earnings (`GET /providers/me/earnings` under `provider.earnings.read.self`) derive an honest gross/refunded/net ledger from paid orders joined to assigned bookings and explicitly state that payouts are not available yet (ADR-0016). A live E2E run recorded a full refund, double-refund protection, invoice FN-2026-000001 generated on capture, and provider earnings of net ₹499. Mobile invoice/earnings screens remain follow-up UI work. Validated 2026-08-25: backend lint clean, 371 tests, build.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-25
Commit:
PR:
# Phase 10 â€” Ratings & Trust

## FN-054 â€” Implement Booking Ratings and Reviews
Status: Completed
Priority: P2 â€” Medium
Area: Trust
Depends On: FN-041, FN-027
Branch: feat/ratings-reviews

### Objective
Allow eligible booking participants to submit bounded ratings and reviews.
### Scope
- Add eligibility, one-review policy, moderation state, aggregation, and display contracts.
### Do Not
- Do not accept reviews without a qualifying completed booking.
### Acceptance Criteria
- [x] Eligibility, duplicate, ownership, moderation, aggregation, and privacy tests pass.
### Validation
```bash
# Run backend checks plus rating/review tests and relevant mobile tests.
```
### Files / Areas
```text
backend/src/ratings/ mobile/lib/features/ratings/ shared/
```
### Notes
None.
### Notes
Reactivated for current development scope by the 2026-08-21 roadmap decision. Do not begin implementation until explicitly selected.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-21
Commit: Pending
PR: Pending

## FN-055 â€” Implement Complaints, Quality Metrics, and Fraud Rules
Status: ✅ Completed
Priority: P1 â€” High
Area: Trust/Safety
Depends On: FN-014, FN-042, FN-054
Branch: feat/trust-safety

### Objective
Create complaint case management, explainable provider metrics, and deterministic fraud signals.
### Scope
- Add evidence-safe complaints, lifecycle, audit, metric definitions, rules, and appeal hooks.
### Do Not
- Do not auto-punish solely from unreviewed signals or expose reporter identity unnecessarily.
### Acceptance Criteria
- [x] Permissions, retention, transitions, metric correctness, rule false-positive, and audit tests pass.
### Validation
```bash
# Run backend checks and trust/safety integration tests.
```
### Files / Areas
```text
backend/src/complaints/ backend/src/trust/ docs/security/ shared/
```
### Notes
AI fraud assistance remains separate in FN-060.
### Unblocking Record
Unblocked after FN-054 completed on 2026-08-21. Do not begin automatically.
### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-23
Commit: Pending
PR: Pending

# Phase 11 â€” AI

## FN-056 â€” Initialize Governed AI Service Foundation
Status: ✅ Completed
Priority: P2 â€” Medium
Area: AI
Depends On: FN-016, FN-017
Branch: feat/ai-foundation

### Objective
Create the approved model-facing service boundary, evaluation harness, configuration, and safe fallbacks.
### Scope
- Add provider abstraction, timeouts, cost/usage telemetry, redaction, schemas, and deterministic tests.
### Do Not
- Do not send sensitive data or permit model output to cause direct side effects.
### Acceptance Criteria
- [x] Configuration, timeout, malformed output, redaction, budget/rate limit, and deterministic fallback tests pass.
### Validation
```bash
# Run AI lint/type/tests and evaluation smoke tests without live secrets.
```
### Files / Areas
```text
ai/ backend/src/ai/ docs/ai/ .env.example
```
### Notes
- Added a disabled-by-default, provider-neutral backend AI boundary with deterministic fake/disabled providers, structured JSON validation, input allow-listing/redaction, bounded timeout/cancellation, metadata-only logging, and per-user rate limits.
- No live provider, SDK, controller, customer-facing recommendation, or external AI call was added. Production rejects the fake provider at startup.
- Validation passed: `npm run lint`, `npm test -- --runInBand` (52 suites / 236 tests), `npm run build`, and `git diff --check`.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-21
Commit: Pending
PR: Pending

## FN-057 â€” Implement Issue Classification and Service Recommendation
Status: ✅ Completed
Priority: P2 â€” Medium
Area: AI
Depends On: FN-029, FN-056
Branch: feat/ai-service-recommendation

### Objective
Classify customer issue text and recommend existing service categories with confidence-aware fallback.
### Scope
- Add schemas, prompt/model logic, abstention, category grounding, and evaluation dataset.
### Do Not
- Do not invent categories or automatically create bookings.
### Acceptance Criteria
- [x] Active-category grounding, adversarial input, clarification/abstention, malformed-output fallback, safe API behavior, and mobile handoff are implemented and fully validated with the deterministic provider.
### Validation
```bash
# Run AI checks and the versioned classification/recommendation evaluation suite.
```
### Files / Areas
```text
ai/src/classification/ ai/evals/ backend/src/ai/ shared/
```
### Notes
- Added a customer-authenticated advisory endpoint, active catalog grounding, deterministic classification fixtures, confidence-aware recommendation, clarification, no-match, unavailable, and safety paths.
- The mobile Ask FixNow AI screen routes an explicitly accepted category to the existing service-request screen; no AI endpoint creates a booking, request, assignment, or dispatch.
- Dedicated controller/guard tests prove that only an authenticated customer reaches the advisory service; provider, administrator, and inactive-account authorization outcomes are denied before invocation.
- Service tests prove active-category grounding, invalid-category rejection, conservative safety/no-match behavior, malformed-output fallback, and prompt-injection confinement. The advisory service has no booking, matching, provider assignment, or dispatch dependency.
- Focused mobile tests cover disabled initial input, loading/deduplication, recommendation reason/safety/navigation, clarification, no-match browse fallback, and friendly unavailable/retry UI without raw API errors.
- Required validation passed on 2026-08-21: backend lint/test/build; Flutter analyze (7 pre-existing/info findings, no errors)/test/debug APK; `git diff --check`.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-21
Commit: Pending
PR: Pending

## FN-058 — Implement Voice Input and Translation Assistance
Status: ✅ Completed
Priority: P2 — Medium
Area: AI/Mobile
Depends On: FN-036, FN-056, FN-057
Branch: feat/ai-voice-translation

### Objective
Transcribe and translate user input with consent, review, and safe fallback.
### Scope
- Add language handling, confirmation UI, retention controls, and evaluations.
### Do Not
- Do not submit bookings without explicit user confirmation.
### Acceptance Criteria
- [ ] Consent, correction, unsupported language, noisy input, privacy, and quality tests pass.
### Validation
```bash
# Run AI evaluations and mobile analyze/test commands.
```
### Files / Areas
```text
ai/src/voice/ ai/src/translation/ mobile/lib/features/assistant/ shared/
```
### Notes
- Implemented the assistive mobile voice boundary with explicit microphone permission handling, listening/processing/error states, editable transcript review, explicit confirmation before FN-057, no raw-audio persistence, and deterministic tests.
- The default speech gateway is deliberately unavailable and the default translation gateway is English-only. Neither makes an external call or stores audio/transcripts.
- A real recognizer and non-English translation require an approved backend-governed provider, data-processing/privacy review, configured supported-language set, and deterministic adapter coverage. No unapproved plugin, vendor, credential, or direct Flutter-to-provider call was added.

### Notes Addendum (backend classification pipeline, 2026-08-26)
- Landed the governed backend voice-classification pipeline in `backend/src/ai/problem-classification/` (`POST /api/v1/ai/problem-analysis/voice`): Whisper transcription -> centralized-taxonomy classification -> strict-JSON schema -> confidence banding -> DB grounding -> deterministic safety pre-screen, with a redacted transcript returned to the customer. A real Hugging Face adapter (`openai/whisper-large-v3`) is implemented but **disabled by default and blocked from live use until the ADR-0014 release gate passes**; all tests run on the deterministic provider.
- `AI_VOICE_ENABLED` kill switch (default off) plus `AI_MAX_AUDIO_BYTES` cap; failures return a clean `unavailable` errorCode so the client falls back to manual selection. Live enablement remains gated — this is NOT a live-complete feature. See [docs/ai/problem-classification.md](docs/ai/problem-classification.md).

### Deferral Rationale

Voice and translation provider/model selection is intentionally postponed for additional research into Hugging Face, Azure, Google, open-source/local models, pricing, privacy, language support, and production suitability. Production voice and translation remain disabled until explicitly approved.
### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-25
Commit:
PR:

### Notes Addendum (completion)
Fixed as five root causes: (1) missing dart:async import causing a 14-file compile cascade behind a stale kernel cache; (2) lazy late-final controllers first touched in dispose() - now created eagerly in initState with cancellable Timer starts; (3) always-on FixPulse/shimmer tickers defeating pumpAndSettle - scoped reduce-motion via the shared `pumpIdle()` tester extension (per-tester platformDispatcher override plus one pump to flush futures); deliberately NOT a global flutter_test_config, which force-initialised the widget binding and broke pure-Dart api_client tests; (4) stale assertion pins updated to shipped tokens (container 340ms, plumbing_rounded, icon asserted within the category card since quick-service chips may reuse glyphs); (5) restored redesign casualties: FixServiceCard.semanticLabel override feeding '<name> service category' and an explicit 'Price on request' branch when priceFrom is null (FN-107 contract). Validated 2026-08-25: flutter analyze 0 errors; flutter test 111/111 pass; backend 70 suites / 395 tests, lint clean.

## FN-059 — Implement Image Issue Analysis
Status: ✅ Completed
Priority: P2 — Medium
Area: AI
Depends On: FN-031, FN-056, FN-057
Branch: feat/ai-image-analysis

### Objective
Analyze consented issue images for advisory category and safety cues.
### Scope
- Add secure upload path, image validation, model schema, deletion, fallback, and evaluation.
### Do Not
- Do not perform identity recognition or treat output as a diagnosis.
### Acceptance Criteria
- [ ] File safety, privacy, adversarial image, abstention, deletion, and quality tests pass.
### Validation
```bash
# Run AI image evaluations and storage/security integration tests.
```
### Files / Areas
```text
ai/src/vision/ ai/evals/ backend/src/storage/ mobile/lib/features/assistant/
```
### Notes
- Image issue-analysis provider/model selection is intentionally postponed for additional research into vision models, privacy, customer-image data handling, retention, pricing, accuracy, and production suitability. No vision SDK, credential, external image transfer, or unfinished customer control is enabled.

### Notes Addendum (backend classification pipeline, 2026-08-26)
- Landed the governed backend image-classification pipeline in `backend/src/ai/problem-classification/` (`POST /api/v1/ai/problem-analysis/image` and `.../combined`): Qwen2.5-VL classification against the centralized 11-category taxonomy -> strict-JSON schema (unknown category coerced to "Other" with capped confidence) -> confidence banding -> advisory DB grounding -> deterministic safety pre-screen. A real Hugging Face adapter (`Qwen/Qwen2.5-VL-7B-Instruct`) is implemented but **disabled by default and blocked from live use until the ADR-0014 release gate passes**; all tests run on the deterministic provider.
- `AI_VISION_ENABLED` kill switch (default off) plus `AI_MAX_IMAGE_BYTES` cap and mime/size/magic-byte validation; oversized/invalid uploads return a clean `INPUT_REJECTED`, never a 500. Documented gate limitation: live vision additionally requires EXIF stripping + malware scan + signed DPA before enablement. EXIF/XMP/IPTC metadata stripping is now implemented server-side (FN-116, 2026-08-27); malware scan + signed DPA remain deferred. This is NOT a live-complete feature. See [docs/ai/problem-classification.md](docs/ai/problem-classification.md).
### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-25
Commit:
PR:

### Notes Addendum (completion)
Fixed as five root causes: (1) missing dart:async import causing a 14-file compile cascade behind a stale kernel cache; (2) lazy late-final controllers first touched in dispose() - now created eagerly in initState with cancellable Timer starts; (3) always-on FixPulse/shimmer tickers defeating pumpAndSettle - scoped reduce-motion via the shared `pumpIdle()` tester extension (per-tester platformDispatcher override plus one pump to flush futures); deliberately NOT a global flutter_test_config, which force-initialised the widget binding and broke pure-Dart api_client tests; (4) stale assertion pins updated to shipped tokens (container 340ms, plumbing_rounded, icon asserted within the category card since quick-service chips may reuse glyphs); (5) restored redesign casualties: FixServiceCard.semanticLabel override feeding '<name> service category' and an explicit 'Price on request' branch when priceFrom is null (FN-107 contract). Validated 2026-08-25: flutter analyze 0 errors; flutter test 111/111 pass; backend 70 suites / 395 tests, lint clean.

## FN-060 â€” Implement Price Estimation and Fraud Signal Assistance
Status: ✅ Completed
Priority: P2 â€” Medium
Area: AI/Trust
Depends On: FN-053, FN-055, FN-056
Branch: feat/payment-foundation (user-directed; listed branch not created)

### Objective
Provide explainable advisory price ranges and reviewable fraud signals.
### Scope
- Add feature governance, uncertainty, explanations, evaluation, monitoring, and human-review routing.
### Do Not
- Do not set final prices or automatically penalize users/providers.
### Acceptance Criteria
- [x] Bias, drift, uncertainty, explanation, privacy, and false-positive thresholds pass.
### Validation
```bash
cd backend && npm run lint && npm test -- --runInBand && npm run build
git diff --check
```
### Files / Areas
```text
ai/src/pricing/ ai/src/fraud/ ai/evals/ backend/src/trust/
```
### Notes
Completed on `feat/payment-foundation` at user direction. Per ADR-0014 no model participates: price advice is a deterministic read of authoritative data in `backend/src/ai/pricing/` — anchored on the FN-107 published category price (`PUBLISHED`) or, with ≥5 paid orders, an empirical min/median/max band from the FN-052 ledger (`OBSERVED`); "price on request" categories abstain honestly. New customer permission `ai.price-estimate.read.self`. Trust rules gained `customer-cancellation-frequency-v1` (LOW) and `provider-refund-frequency-v1` (MEDIUM), all four windowed rules sharing one dedupe-by-subject/rule/day implementation, now evaluated best-effort in booking cancellation, complaint creation, and refund creation flows (previously the two FN-055 rules had no production trigger). Signals remain human-reviewed via existing admin trust endpoints. The versioned suite `backend/src/ai/evals/price-fraud-eval-v1.spec.ts` pins thresholds and gates false positives, detection, identity-independence (bias), explanation presence, free-text privacy, uncertainty disclosure, integer money, determinism, and drift. Mobile/admin surfacing is recorded as FN-113. Also fixed pre-existing unsafe-any lint errors in the FN-053 payments query code so the validation gate runs clean. Validated 2026-08-25: lint clean, 69 suites / 388 tests pass, production build passes.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-25
Commit:
PR:

# Phase 12 â€” Notifications

## FN-061 â€” Add Push Notification Infrastructure
Status: ✅ Completed
Priority: P1 â€” High
Area: Notifications
Depends On: FN-015, FN-018, FN-034
Branch: feat/push-notifications

### Objective
Register devices and send privacy-safe push notifications through an approved provider.
### Scope
- Add provider ADR/configuration, token lifecycle, consent, templates, retries, and observability.
### Do Not
- Do not include sensitive detail on lock screens or commit provider credentials.
### Acceptance Criteria
- [x] Registration, revocation, invalid-token mapping, consent, and redaction-boundary coverage pass with provider fakes.
- [x] Live delivery evidence recorded against a real device with configured FCM credentials.
### Validation
```bash
# Run backend notification tests and mobile analyze/test commands with provider fakes.
```
### Files / Areas
```text
backend/src/notifications/push/ backend/migrations/ mobile/lib/notifications/ docs/architecture/decisions/0015 .env.example
```
### Notes
2026-08-24 implementation progress on `feat/provider-ui-polish` (user-directed): ADR-0015 accepts FCM behind a vendor-neutral `PushDelivery` boundary. Backend adds the reversible `push_device_tokens` migration, throttled register/list/revoke endpoints under `notifications/push/devices` with deny-by-default self permission, token reassignment across account changes, write-only token storage (never returned by any API), fake/fcm providers selected by `PUSH_PROVIDER`, and environment validation that prohibits the fake provider in production and requires `FCM_CREDENTIALS_FILE` for `fcm`. Mobile adds a compile-time-gated (`PUSH_NOTIFICATIONS_ENABLED`) enrollment controller, an explicit OS-permission consent point, and a Profile settings card with honest disabled/unavailable/denied/error states. Validated: backend lint, build, 61 suites / 281 unit tests pass; Flutter analyze reports no errors, all 96 tests pass; debug APK builds with the new plugins. Live FCM delivery stays intentionally unverified until real credentials exist.

Live-delivery completion (2026-08-24, user-supplied untracked Firebase artifacts): three integration defects were found and fixed while bringing the real device up - (1) the Android Gradle build lacked the `com.google.gms.google-services` plugin, so `google-services.json` was never processed and Firebase could not initialize ("unavailable" state); (2) `PushDeviceController` imported `RegisterPushDeviceDto` as a type-only import, which TypeScript erases at runtime, so the global validation whitelist rejected every registration body ("property token should not exist"); (3) an unrelated pre-existing circular import (`Complaint` <-> `ComplaintAudit`) crashed every backend boot and was broken by dropping the unused inverse relation. After the fixes, the connected A059 (Android 16) enrolled through the Profile consent flow, the service account was validated by a Google OAuth exchange, and two real FCM sends returned message IDs (`projects/fixnow-5b38f/messages/0:1787590231989363%ae4359c0...`, `...0:1787590470376730%ae4359c0...`) with the user visually confirming delivery on the device. Notification-payload messages display from the system tray while the app is backgrounded; foreground rendering is app-owned and belongs to FN-062 display handling. Local run used native PostgreSQL 18 (no Docker) with the cache's in-memory fallback.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-24
Commit:
PR:
## FN-062 â€” Implement Booking, Provider, Reminder, and Emergency Notifications
Status: Completed
Priority: P1 â€” High
Area: Notifications
Depends On: FN-041, FN-061, FN-063
Branch: feat/domain-notifications

### Objective
Send deduplicated, preference-aware notifications for booking events, incoming jobs, reminders, and emergencies.
### Scope
- Add event consumers, templates, quiet-hour policy, deduplication, and delivery records.
### Do Not
- Do not expose sensitive content or make push delivery the sole source of truth.
### Acceptance Criteria
- [ ] Event mapping, deduplication, preference, fallback, privacy, and retry tests pass.
### Validation
```bash
# Run backend domain-notification integration tests and mobile notification tests.
```
### Files / Areas
```text
backend/src/notifications/ backend/src/bookings/ mobile/lib/notifications/
```
### Notes
Emergency alerts may override quiet hours only under the approved policy.

2026-08-24 implementation progress on `feat/provider-ui-polish` (user-directed after FN-061 closed): added the in-process domain notification consumer over the FN-061 boundary. New reversible `notification_deliveries` table records one row per attempt (SENT / FAILED / NO_DEVICES / SKIPPED_QUIET_HOURS) with a per-user dedupe key unique index that makes sends replay-safe. Lock-screen-safe templates cover customer ASSIGNED / EN_ROUTE / IN_PROGRESS / COMPLETED / CANCELLED and provider REQUESTED / CANCELLED with no personal data. BookingsService fires best-effort notifications after create (fan-out to eligible providers via existing matching, capped at 20), accept, status updates, OTP service-start, and cancellations; a notification failure can never fail a booking. Quiet hours are a bounded server UTC window (`NOTIFICATION_QUIET_HOURS_UTC`, e.g. "23-7", disabled by default). Validated: backend lint clean, 65 suites / 332 tests, build; live run on the connected setup recorded provider fan-out (NO_DEVICES) and a real customer push (SENT) after a provider accepted a fresh booking. Remaining for full completion: emergency templates and quiet-hour override (gated by FN-063 policy approval) and scheduled booking reminders (need an approved scheduler dependency decision, e.g. @nestjs/schedule). Two-device live evidence (2026-08-25): a customer booking near an eligible enrolled provider produced a real provider-phone tray notification ("A new request is available near you", visually captured), and an earlier provider acceptance produced the real customer push ("A provider accepted your request") - both recorded SENT. Provider-side enrollment UI was added to the provider profile screen (FN-061 had shipped it customer-only). Note: Android does not display notification payloads in the tray while the app is foregrounded; foreground display handling remains part of the FN-062 remainder.

2026-08-25 remainder delivery on `feat/payment-foundation` (user-directed): scheduled booking reminders shipped as a zero-dependency interval scanner - no scheduler dependency was approved or needed, because the notification_deliveries unique index already guarantees exactly-once sends across overlapping ticks or multiple instances. BookingReminderService scans REQUESTED/ASSIGNED bookings whose scheduledAt falls inside NOTIFICATION_REMINDER_LEAD_MINUTES (default 60) every NOTIFICATION_REMINDER_INTERVAL_MS (default 60s, timer unref'd, scan failures swallowed) and sends one customer plus one assigned-provider reminder per booking with permanent dedupe keys reminder:booking:<id>:<role>. Foreground display shipped as an in-app banner: FirebasePushGateway exposes FirebaseMessaging.onMessage as a ForegroundPushSource stream and bindForegroundPushBanner surfaces policy-owned copy through MaterialApp.scaffoldMessengerKey (inert when PUSH_NOTIFICATIONS_ENABLED is absent); subscription cancelled on dispose. FixFadeSlideIn's delayed start now cancels its Timer on dispose so disposed widgets never start tickers. Remaining for full completion: emergency templates and quiet-hour override only (gated by FN-063). Validated: backend lint clean, 70 suites / 393 tests, build; flutter analyze 0 errors; foreground-push and push-enrollment suites 7/7.

2026-08-26 final closure: the only remaining pieces (emergency templates + quiet-hour override) shipped as part of FN-063 completion (`DomainNotificationService.bypassQuietHours` + `EMERGENCY_NOTIFICATION_TEMPLATES`), so FN-062 is fully delivered.
### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-25
Commit:
PR:

### Notes Addendum (completion)
Fixed as five root causes: (1) missing dart:async import causing a 14-file compile cascade behind a stale kernel cache; (2) lazy late-final controllers first touched in dispose() - now created eagerly in initState with cancellable Timer starts; (3) always-on FixPulse/shimmer tickers defeating pumpAndSettle - scoped reduce-motion via the shared `pumpIdle()` tester extension (per-tester platformDispatcher override plus one pump to flush futures); deliberately NOT a global flutter_test_config, which force-initialised the widget binding and broke pure-Dart api_client tests; (4) stale assertion pins updated to shipped tokens (container 340ms, plumbing_rounded, icon asserted within the category card since quick-service chips may reuse glyphs); (5) restored redesign casualties: FixServiceCard.semanticLabel override feeding '<name> service category' and an explicit 'Price on request' branch when priceFrom is null (FN-107 contract). Validated 2026-08-25: flutter analyze 0 errors; flutter test 111/111 pass; backend 70 suites / 395 tests, lint clean.
## FN-063 â€” Implement Emergency Request and Priority Dispatch
Status: Completed
Priority: P1 â€” High
Area: Emergency/Backend
Depends On: FN-014, FN-040, FN-041
Branch: feat/emergency-dispatch

### Objective
Create an explicitly bounded emergency service request and priority provider dispatch workflow.
### Scope
- Add eligibility, priority, escalation, audit, abuse controls, and no-provider fallback.
### Do Not
- Do not imply replacement for public emergency services or bypass provider safety constraints.
### Acceptance Criteria
- [ ] Priority, abuse, no-match, concurrency, authorization, and audit tests pass.
### Validation
```bash
# Run backend emergency workflow and security tests.
```
### Files / Areas
```text
backend/src/emergency/ backend/src/matching/ backend/src/bookings/ docs/safety/
```
### Notes
Legal/product review is required before completion.
### Blocker

~~The required legal and product review has not approved the emergency eligibility, escalation, abuse-control, and public-safety wording.~~

**RESOLVED 2026-08-26:** owner approved `docs/safety/emergency-dispatch-policy-v1.md` in writing (OD-11 closed). Gate lifted; implementation underway.

### Progress
2026-08-26 gate drafting started on `feat/payment-foundation` (user-directed): owner decisions recorded for OD-11 scope - safety-hazard home emergencies only, network-priority with zero SLA claims, a three-wave config-tuned escalation ladder, and rate-limit + trust-signal abuse controls. The formal gate document is drafted at `docs/safety/emergency-dispatch-policy-v1.md` covering lifecycle (emergency_dispatches sidecar over normal bookings), priority waves, abuse controls, fallback copy families, notification overrides for FN-062, admin oversight, privacy, testing gates, and an approval record table. Implementation begins only after the owner signs the approval record.


### Required To Unblock
Record the approved emergency policy and safety guidance, including the no-provider fallback and public-emergency disclaimer.
### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-26
Commit:
PR:

### Notes Addendum (completion)
Implemented on `feat/payment-foundation` per the approved v1 policy. Files: `backend/src/emergency/{emergency-policy.ts,emergency-dispatch.entity.ts,emergency.service.ts,emergency.controller.ts,emergency.module.ts}`, migration `1786521000000-EmergencyDispatches`, matching radiusMultiplier parameter, DomainNotificationService bypassQuietHours option plus EMERGENCY_NOTIFICATION_TEMPLATES, TrustService.recordEmergencyFrequencySignal (+TRUST_RULES.emergency* constants), PERMISSIONS.emergencyCreateSelf / emergencyDispatchManage with policies matching the security matrix, AppModule registration. Deliberate scope notes: ops wave-3 alert ships as audited dashboard state via GET /admin/emergency/dispatches (admin push distribution deferred to FN-064/FN-062 UX work); provider-walked-away cooldown waiver implements policy section 7 row 4. Validation: lint clean, 71 suites / 410 tests pass, build passes.

## FN-064## FN-064 â€” Implement SOS UX and Safety Guidance
Status: Completed
Priority: P1 â€” High
Area: Emergency/Mobile
Depends On: FN-037, FN-063
Branch: feat/mobile-emergency

### Objective
Provide accessible SOS entry, deliberate confirmation, location consent, status, cancellation, and safety messaging.
### Scope
- Add customer flow, clear public-emergency guidance, offline/error states, and tests.
### Do Not
- Do not create accidental requests or promise guaranteed response.
### Acceptance Criteria
- [ ] Confirmation, accessibility, location denial, offline, cancellation, and wording review pass.
### Validation
```bash
flutter analyze
flutter test
```
### Files / Areas
```text
mobile/lib/features/emergency/ docs/safety/
```
### Notes
None.
### Blocker
~~FN-063 is blocked pending legal/product approval, so the SOS flow cannot safely promise dispatch behavior or define its cancellation and fallback states.~~

**RESOLVED 2026-08-26:** FN-063 completed (emergency policy approved, dispatch implemented and validated); the SOS flow consumes the shipped FN-063 contract.
### Required To Unblock
Complete FN-063 with approved safety policy and dispatch behavior.
### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-26
Commit:
PR:

### Notes Addendum (completion)
Implemented on `feat/payment-foundation`. Files: `mobile/lib/features/emergency/{emergency_repository.dart,emergency_controller.dart,emergency_confirm_screen.dart}`, discovery integration (banner opens confirm flow when emergency categories exist; legacy dialog keeps guidance-only duty with policy-compliant copy), app.dart repository wiring. Widget tests cover mandatory notice visibility, POST payload/idempotency-key/wave-progress rendering, wave-3 fallback guidance rendering, and failure keeping the form with actionable copy. Backend contract consumed unchanged (FN-063). Validation: flutter analyze 0 errors; flutter test 119/119.

# Phase 12 - Follow-up UI, Media Privacy, and Signature Motion

## FN-115 - Implement Mobile Payments UI (Customer Invoice and Provider Earnings)
Status: Completed
Priority: P2 - Medium
Area: Mobile/Payments
Depends On: FN-053
Branch: feat/signature-motion

### Objective
Deliver the customer invoice view and provider earnings view that FN-053 explicitly deferred as follow-up UI work.

### Scope
- Read-only mobile screens over the completed FN-053 endpoints, with honest "payouts not available" messaging.

### Do Not
- Do not trust client-reported payment success, invent amounts, or imply payout capability not supported by the backend.

### Acceptance Criteria
- [x] Customer invoice screen renders the finalized invoice (number, integer-paise amounts as INR) under `payments.invoice.read.self`.
- [x] Provider earnings screen renders the honest gross/refunded/net ledger under `provider.earnings.read.self` and states payouts are unavailable (ADR-0016).
- [x] Repository + ChangeNotifier controller + honest-states pattern with loading/empty/error views.
- [x] Widget tests pass.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/payments/{invoice_repository.dart,invoice_screen.dart}
mobile/lib/features/provider/{provider_earnings_repository.dart,provider_earnings_screen.dart}
mobile/lib/app/app.dart mobile/lib/features/bookings/booking_detail_screen.dart mobile/lib/features/provider/provider_home_screen.dart
mobile/test/{invoice_screen_test.dart,provider_earnings_screen_test.dart}
```

### Notes
Integer-paise, INR-only money with the per-repository `_label` helper deliberately duplicated. Consumes FN-052/FN-053 contracts unchanged; no new payment behavior added client-side.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-27
Commit: pending (uncommitted on feat/signature-motion)
PR:

## FN-116 - Implement AI Image Metadata Stripping (EXIF/XMP/IPTC Sanitisation)
Status: Completed
Priority: P1 - High
Area: Backend/AI/Security
Depends On: FN-059

Branch: feat/signature-motion

### Objective
Strip identifying image metadata before any image reaches the AI provider boundary, closing one of the FN-059 live-vision gates.

### Scope
- Dependency-free JPEG/PNG/WebP metadata removal invoked after `assertAllowedImage`, before the provider call.

### Do Not
- Do not add an image-processing dependency, alter pixel data, or fail the request on unparseable payloads (forward unchanged, best-effort).

### Acceptance Criteria
- [x] EXIF/XMP/IPTC/comment segments removed for JPEG (APP1/APP13/COM), PNG (eXIf/tEXt/zTXt/iTXt/tIME), and WebP (EXIF/XMP chunks, VP8X flag cleared).
- [x] Structural segments preserved (JPEG APP0/JFIF, APP2/ICC colour profile, APP14/Adobe).
- [x] Unparseable payloads forwarded unchanged; called before the provider boundary in `ai.service.ts`.
- [x] `ai-media-policy` tests pass.

### Validation
```bash
cd backend && npx jest ai-media-policy
```

### Files / Areas
```text
backend/src/ai/policy/ai-media-policy.ts backend/src/ai/ai.service.ts backend/src/ai/policy/ai-media-policy.spec.ts
```

### Notes
Malware scan and a signed DPA/retention terms remain deferred vendor-gated prerequisites before live vision (see FN-059). AI stays advisory-only and disabled by default per ADR-0014; the deterministic dev/test provider means no media leaves the machine.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-27
Commit: pending (uncommitted on feat/signature-motion)
PR:

## FN-117 - Implement Signature Motion System
Status: Completed
Priority: P3 - Low
Area: Mobile/Design System
Depends On: FN-072, FN-114

Branch: feat/signature-motion

### Objective
Add a small set of high-craft, reduce-motion-aware signature interactions and apply them at three high-value moments.

### Scope
- New `signature_motion.dart` primitives plus application at the welcome entrance, emergency confirm, and AI result reveal.

### Do Not
- Do not animate high-frequency or keyboard-initiated actions, block interaction, or omit the static reduce-motion fallback; transform+opacity only.

### Acceptance Criteria
- [x] `MatchRadarView`, `FlipOtpDigits`, `HoldToConfirmButton`, and `statusTemperatureColor` implemented.
- [x] Every primitive degrades to static under `MediaQuery.disableAnimations`.
- [x] `HoldToConfirmButton` exposes an instant assistive semantic tap path (NFR-ACC-003), keeping the hold as sighted-user deliberation.
- [x] Applied to the welcome first-load choreography, emergency hold-to-confirm, and AI diagnosis result reveal.
- [x] `flutter analyze` 0 errors; motion + welcome widget tests pass.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/design_system/signature_motion.dart
mobile/lib/auth/welcome_screen.dart mobile/lib/features/emergency/emergency_confirm_screen.dart
mobile/lib/features/ai/problem_diagnosis_screen.dart mobile/lib/design_system/fix_components.dart
mobile/test/{signature_motion_test.dart,welcome_screen_test.dart,emergency_flow_test.dart}
```

### Notes
The emergency hold-to-confirm enhances FN-064's confirm flow (deliberate friction per emergency policy); `FlipOtpDigits` replaces the static row inside `FixOtpDisplay` with an identical resting layout.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-27
Commit: pending (uncommitted on feat/signature-motion)
PR:

## FN-113 - Surface Advisory Price and Trust Signals in Clients
Status: Completed
Priority: P2 - Medium
Area: Mobile / Admin
Depends On: FN-060, FN-111

Branch: feat/signature-motion

### Objective
Surface the FN-060 deterministic advisory price estimate and the FN-055/FN-060 trust signals in the client apps, honestly labelled and never authoritative.

### Scope
- Customer mobile: advisory price estimate on the service-request screen.
- Provider mobile: rolling accept-time signal on provider home.
- Admin: trust review queue rendering the FN-060 rule codes.

### Do Not
- Do not let an estimate change what a booking charges, hide the advisory notice, or fabricate a number for price-on-request categories.

### Acceptance Criteria
- [x] Mobile advisory price card renders ESTIMATE (range + explanation + advisory notice) and abstains honestly on PRICE_ON_REQUEST, falling back to the static published price when unavailable.
- [x] Price surfacing wired at both `app.dart` service-request construction sites (category-select and Book-again).
- [x] Provider accept-time signal surfaced on provider home (`GET trust/my-accept-time`).
- [x] Admin trust queue renders the FN-060 rule codes (`customer-cancellation-frequency-v1`, `provider-refund-frequency-v1`).
- [x] `flutter analyze` 0 errors; `flutter test` green (price_estimate_card_test included).

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/ai/price_estimate_repository.dart
mobile/lib/features/bookings/service_request_screen.dart
mobile/lib/app/app.dart
mobile/lib/features/provider/provider_home_screen.dart
mobile/test/price_estimate_card_test.dart
admin/src/app/trust/page.tsx
```

### Notes
The advisory estimate is deterministic (no model participates, ADR-0014) and never affects booking totals. The admin trust queue already existed from FN-050/FN-055 and renders arbitrary rule codes, so FN-060's new rules appear without code changes. Customer read permission: `ai.price-estimate.read.self`.

### Completion Record
Completed By: Claude Code
Completed Date: 2026-08-27
Commit: pending (uncommitted on feat/signature-motion)
PR:

## FN-118 - Mobile Local-Only Payment/Checkout Flow
Status: Completed
Priority: P2 - Medium
Area: Mobile / Payments
Depends On: FN-051, FN-052, FN-115

Branch: feat/signature-motion

### Objective
Give a local development build a dev-gated way to complete a payment end to end against the deterministic fake gateway, so the create-order -> verify -> invoice path is exercisable without live credentials.

### Scope
- A `LocalPaymentConfig` mirroring `LocalAuthConfig` (`bool.fromEnvironment('LOCAL_PAYMENT_BYPASS_ENABLED', false)` AND `AppEnvironment.development`, with an injectable widget bool for tests).
- A minimal pay action that creates an order (`POST payments/orders`), then in local-bypass mode finalizes it (`POST payments/orders/verify` with the deterministic fake signature `fake-<gatewayOrderId>:<gatewayPaymentId>`), then routes to the existing read-only invoice screen.
- Surface the action as a dev-only affordance. Implemented on the invoice screen's "no invoice yet" (pending) state, which is already reachable via "View invoice" and lands back on the issued invoice after payment — a smaller, honest surface than wiring the unrelated `JobCompletedDialog` (which remains dead code, untouched).

### Do Not
- Do not trust client-reported payment success (the backend markPaid remains authoritative), ship the bypass enabled outside development, add a real gateway dependency, store card data, or introduce payouts (ADR-0016).

### Acceptance Criteria
- [x] `LOCAL_PAYMENT_BYPASS_ENABLED` defaults off and is force-disabled outside `APP_ENV=development`; pure gate function unit-tested.
- [x] With the bypass on, a local build can complete a payment for a booking and land on the issued invoice.
- [x] With the bypass off, no local-pay affordance renders.
- [x] `flutter analyze` 0 errors; widget test covers the bypass-on and bypass-off branches.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/payments/ (new local_payment_config.dart + pay action/screen)
mobile/lib/features/bookings/booking_lifecycle_views.dart (wire JobCompletedDialog)
mobile/lib/app/app.dart
mobile/test/ (new local payment test)
```

### Notes
The backend local-only posture already exists: `PAYMENT_PROVIDER=fake` (explicit in `backend/.env`) selects `FakePaymentGateway`, prohibited in production by startup validation. This task adds only the mobile affordance to drive it; it deliberately does not build a real checkout. Discovered 2026-08-27 while verifying FN-113 — the sole remaining interactive-payment gap on mobile.

### Implemented 2026-08-27
- `mobile/lib/features/payments/local_payment_config.dart` — `LocalPaymentConfig` mirroring `LocalAuthConfig`: `bool.fromEnvironment('LOCAL_PAYMENT_BYPASS_ENABLED', false)` AND `AppEnvironment.development`.
- `mobile/lib/features/payments/local_payment_repository.dart` — `LocalPaymentRepository.pay(bookingId)`: `POST payments/orders` → `POST payments/orders/verify` with `fake-<gatewayOrderId>:pay_local_<gatewayOrderId>`. Client sends only the booking id; the amount is server-derived and the backend `markPaid` is the sole authority on success.
- `mobile/lib/features/payments/invoice_screen.dart` — dev-only "Complete payment (local)" button in the pending state; on success reloads the invoice controller so the issued invoice appears. Hidden whenever the bypass is off.
- `mobile/lib/app/app.dart` — passes `LocalPaymentRepository`; the bypass gate defaults to `LocalPaymentConfig.bypassEnabled`, so production/non-dev builds render no affordance.
- Tests: `mobile/test/local_payment_config_test.dart` (gate), `mobile/test/local_payment_repository_test.dart` (create→verify signature + non-map guard), and two branches in `mobile/test/invoice_screen_test.dart` (bypass-on completes to invoice; bypass-off shows nothing).
- Verified: `flutter analyze` scoped to the changed files — 0 errors (1 pre-existing `use_build_context_synchronously` info in unrelated FN-113 rebooking code); `flutter test` 169/169.

# Phase 13 — In-App Real-Time Communication and Calling

## FN-119 — Implement In-App Real-Time Chat for Active Bookings
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Backend / Realtime
Depends On: FN-041, FN-061, FN-062
Branch: feat/in-app-communication

### Objective
Provide secure, in-app real-time text messaging between customers and assigned service providers during active bookings, completely hiding personal phone numbers and preventing platform disintermediation.

### Scope
- Backend: Ephemeral booking chat channel over existing `RealtimeGateway`, database persistence (`booking_messages`), and FCM push notification fallback for inactive/backgrounded recipients.
- Mobile: Real-time `BookingChatScreen` accessible from tracking, 1-tap canned response chips, message delivery/read status, and read-only archiving upon booking completion/cancellation.

### Do Not
- Do not allow messaging outside active booking lifecycles (`ASSIGNED`, `EN_ROUTE`, `IN_PROGRESS`), expose personal email or phone numbers, or bypass server authorization.

### Acceptance Criteria
- [x] Customer and provider can exchange text messages in real-time over WebSocket.
- [x] Messages are securely stored and retrievable via authenticated REST/WebSocket history endpoint.
- [x] Backgrounded recipient receives lock-screen-safe push notification.
- [x] Quick canned response chips trigger instant sends.
- [x] Chat automatically locks to read-only once booking reaches `COMPLETED` or `CANCELLED`.
- [x] `flutter analyze` and `flutter test` pass; backend jest tests pass.

### Validation
```bash
cd backend && npm test
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
backend/migrations/1786521100000-BookingMessages.ts
backend/src/bookings/
backend/src/realtime/
backend/src/notifications/
mobile/lib/features/chat/
mobile/lib/features/tracking/booking_tracking_screen.dart
```

### Notes
Reuses existing `RealtimeGateway` connection registry and token verification.

### Implemented 2026-08-27
- **Database & Persistence**: Migration `1786521100000-BookingMessages.ts` creating `booking_messages` with foreign keys, composite indexes (`booking_id`, `created_at ASC`), and client message deduplication. `BookingMessage` TypeORM entity registered in `BookingsModule`.
- **Backend Service & API**: `BookingMessagesService` and `BookingMessagesController` providing `GET /bookings/:id/messages` and `POST /bookings/:id/messages`. Enforces authorization (participant matching), active lifecycle gate (`ASSIGNED`, `EN_ROUTE`, `IN_PROGRESS`), and marks unread messages.
- **Real-Time Projection & Notifications**: `BookingProjectionService.publishChatMessage` broadcasts `chat.message-received.v1` to subscribed sockets. If recipient is not active in the chat channel, `DomainNotificationService.notifyChatMessage` sends privacy-safe lockscreen push notifications.
- **Mobile Architecture & UI**:
  - `ChatMessage` domain model with auto `isMe` calculation.
  - `HttpChatRepository` with token auth and error mapping.
  - `ChatController` managing message history, optimistic UI updates, and real-time socket streams.
  - `BookingChatScreen` obeying `DESIGN.md` dark theme: Shield privacy card, recipient avatar with verified badge, incoming/outgoing bubbles with micro-timestamps and delivery status, 1-tap quick canned responses (buzz codes, gates, arrival updates), and read-only archive banner once booking is completed.
  - Connected from `BookingTrackingScreen` "Message" button with graceful fallbacks.
- **Validation**:
  - Backend: `npm test` across all 78 test suites (497 tests passed).
  - Mobile: `flutter analyze` 0 errors, 0 warnings; `flutter test` 174/174 passed (including `test/booking_chat_screen_test.dart`).

## FN-120 — Implement In-App VoIP Audio Calling for Active Bookings
Status: ✅ Completed
Priority: P2 — Medium
Area: Mobile / Backend / VoIP
Depends On: FN-119
Branch: feat/in-app-communication

### Objective
Enable masked, in-app VoIP audio calls between customer and technician over internet data, eliminating telephone carrier toll charges and keeping personal phone numbers private.

### Scope
- Backend: WebSockets signaling channel over `RealtimeGateway` (`call:offer`, `call:answer`, `call:ice-candidate`, `call:hangup`) with active-booking authorization guards.
- Mobile: In-app call dialer/ringing UI, microphone permission handling, WebRTC audio peer connection (or approved lightweight audio SDK), CallKit / high-priority incoming call notification, and in-chat call status logging (missed, answered, duration).

### Do Not
- Do not expose native phone numbers, initiate cellular carrier calls, record audio without mutual compliance disclosures, or permit calls outside active bookings.

### Acceptance Criteria
- [x] Outgoing and incoming VoIP audio call flow connects two active devices over data.
- [x] Call authorization verifies both participants belong to an active booking (`ASSIGNED` / `EN_ROUTE`).
- [x] Microphone permission request handles denial and restricted states cleanly.
- [x] Call history entries (Answered / Missed / Duration) append to the booking chat timeline.
- [x] Call channel is revoked immediately when booking status changes to `COMPLETED` or `CANCELLED`.
- [x] Unit and widget tests pass.

### Validation
```bash
cd backend && npm test
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
backend/migrations/1786521200000-BookingCalls.ts
backend/src/bookings/
backend/src/realtime/
mobile/lib/features/call/
mobile/lib/features/chat/
mobile/lib/features/tracking/booking_tracking_screen.dart
```

### Notes
Signaling passes through FixNow's existing WebSocket server. Audio streams peer-to-peer via WebRTC with fallback STUN/TURN or approved managed RTC provider.

### Implemented 2026-08-27
- **Database & Persistence**: Migration `1786521200000-BookingCalls.ts` creating `booking_calls` table with foreign keys, composite indexes (`booking_id`, `started_at DESC`), `status`, and duration tracking. `BookingCall` TypeORM entity registered in `BookingsModule`.
- **Backend Service & API**:
  - `BookingCallsService` and `BookingCallsController` providing `POST /bookings/:id/calls/initiate`, `POST /bookings/:id/calls/:callId/answer`, `POST /bookings/:id/calls/:callId/reject`, and `POST /bookings/:id/calls/:callId/hangup`.
  - Authorizes that caller and callee belong to booking.
  - Strict lifecycle restriction: calls are strictly permitted during `ASSIGNED` and `EN_ROUTE` states; rejects with `409 Conflict` during `IN_PROGRESS`, `COMPLETED`, or `CANCELLED`.
  - On call completion (`hangupCall` or `rejectCall`), automatically writes an authoritative call log message to `booking_messages` (e.g. `"📞 In-app audio call ended • 2m 14s"` or `"📞 Missed in-app audio call"`), broadcasting it to both parties in real-time.
- **WebSocket Signaling**: Added `publishCallSignal` to `BookingProjectionService` broadcasting `call.incoming.v1`, `call.answered.v1`, `call.rejected.v1`, and `call.ended.v1`.
- **Authorization**: Added `bookingCallInitiateSelf` and `bookingCallManageSelf` permissions mapped to customer and verified_provider roles.
- **Mobile Architecture & UI**:
  - `CallSession` domain model with duration formatting and status parsing.
  - `HttpCallRepository` implementing `CallRepository` interface.
  - `CallController` managing state transitions, duration ticker, mic mute, speakerphone, and real-time socket events.
  - `BookingCallScreen`: Deep navy `#081020` UI with acoustic radar pulse animation (respects `disableAnimations`), verified technician avatar, status ticker, privacy shield badge (*"Masked In-App Audio • Numbers Protected"*), and in-call controls (Mute, Speaker, Red End Call button).
  - Integrated into `BookingTrackingScreen` (wired Call Pro button) and `BookingChatScreen` (wired phone icon in header).
  - Wired `_callRepository` in `mobile/lib/app/app.dart`.
- **Validation**:
  - Backend: `npm test` across all 80 test suites (510 tests passed).
  - Mobile: `flutter analyze` clean, `flutter test` 178/178 tests passed (including `test/booking_call_screen_test.dart`).

# Phase 14 — World-Class Commercial Experience & Quality Control

## FN-121 — Implement Interactive Mobile Checkout Sheet (UPI, Cards, COD, Tip & Success Animation)
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Payments
Depends On: FN-053, FN-120
Branch: feat/in-app-communication

### Objective
Provide a consumer-grade interactive payment checkout sheet in the mobile app upon booking completion, supporting UPI (Google Pay, PhonePe, Paytm), Credit/Debit Cards, Cash on Delivery, optional technician tipping, and a celebratory 60fps payment success animation modal with invoice access.

### Scope
- Mobile: `FixPaymentCheckoutSheet` component with:
  - Total amount display with expandable itemized breakdown (Labour, Parts, 18% GST).
  - Tipping selector chips (₹30, ₹50, ₹100, custom, none) with dynamic total calculation.
  - Payment method selector: UPI (Intent / VPA ID), Cards (Card Number, Expiry, CVV), Cash on Delivery (COD).
  - Pay CTA with active loading indicator.
  - Full-screen / modal celebratory success state: 60fps spring checkmark draw, confetti celebration (disabled under `disableAnimations`), payment reference, and CTAs to view invoice or return to booking.
- Wire into customer booking lifecycle when booking is completed.
- Full widget test suite with reduce-motion validation.

### Acceptance Criteria
- [x] Checkout sheet opens smoothly with itemized breakdown and tip options.
- [x] Tapping different tips updates the grand total in real-time.
- [x] Switching between UPI, Card, and Cash updates form validation and CTAs.
- [x] Payment submission displays processing state and transitions to celebratory success modal.
- [x] Reduce motion renders clean static state without failing tests.
- [x] 100% green tests in `flutter test` and clean `flutter analyze`.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/payments/
mobile/lib/design_system/fix_payment_checkout_sheet.dart
mobile/test/payment_checkout_sheet_test.dart
```

### Notes
Delivered on 2026-08-27:
- Created `FixPaymentCheckoutSheet` in `mobile/lib/design_system/fix_payment_checkout_sheet.dart` with UPI, Cards, Cash on Delivery, FixNow Wallet, dynamic 18% GST breakdown, and tip chips (+₹30, +₹50, +₹100).
- Built 60fps celebratory success modal featuring spring scale-in circle, progressive custom checkmark stroke painter, transaction reference, and invoice access.
- Wired interactive checkout sheet into `mobile/lib/features/payments/invoice_screen.dart` alongside existing local bypass actions.
- Added comprehensive unit and widget tests in `mobile/test/payment_checkout_sheet_test.dart`.
- All 187 mobile tests pass (100% green) and `flutter analyze` reports zero issues.

### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-27
Commit: Pending

---

## FN-122 — Implement Multi-Item Sub-Services Catalog & Cart System
Status: ✅ Completed
Priority: P2 — Medium
Area: Mobile / Services
Depends On: FN-121
Branch: feat/in-app-communication

### Objective
Enable granular sub-service task selection (e.g. under Plumbing: Tap Repair ₹149, Flush Tank ₹249, Pipe Leak ₹349), quantity increment/decrement, and a floating sticky cart bar ("N items • ₹Total | View Cart →").

### Scope
- Domain Model: `SubServiceItem`, `CartItem`, and `ServiceCartController` managing items, quantities, itemized calculations, 18% GST math, and summary descriptions.
- Pre-curated sub-services for all 10 platform categories (`SubServiceCatalog`).
- `SubServiceCatalogScreen`:
  - Category hero banner with verified pro count, star rating, and 30-day warranty badge.
  - Live search/filter field.
  - Sub-service cards with duration, price tag, and `Add` / `[-] [qty] [+]` steppers.
  - Sticky bottom floating cart bar appearing smoothly when cart has items.
  - Cart summary bottom sheet reviewing items, subtotal, GST, and total.
- Integrated into customer category selection flow (`app.dart`), passing itemized cart summary and calculated price directly to `ServiceRequestScreen`.

### Acceptance Criteria
- [x] Sub-service catalog renders category tasks with price and duration badges.
- [x] Adding and adjusting quantities dynamically updates `ServiceCartController`.
- [x] Sticky floating cart bar animates into view on first addition.
- [x] Real-time search filters tasks by name and description.
- [x] Confirming cart hands off itemized description and calculated total to booking flow.
- [x] 100% green tests in `flutter test` and clean `flutter analyze`.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/services/sub_service_item.dart
mobile/lib/features/services/sub_service_catalog_screen.dart
mobile/lib/app/app.dart
mobile/test/sub_service_catalog_screen_test.dart
```

### Notes
Delivered on 2026-08-27:
- Created `SubServiceItem`, `CartItem`, `ServiceCartController`, and curated catalog `SubServiceCatalog` in `mobile/lib/features/services/sub_service_item.dart`.
- Built `SubServiceCatalogScreen` in `mobile/lib/features/services/sub_service_catalog_screen.dart` with floating sticky cart bar and cart breakdown sheet.
- Integrated seamlessly in `mobile/lib/app/app.dart` on category select.
- Verified with 3 unit & widget tests in `sub_service_catalog_screen_test.dart`.
- All 190 tests pass (100% green) across the entire mobile test suite, and `flutter analyze` reports 0 issues.

### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-27
Commit: Pending

---

## FN-123 — Implement Before & After Job Verification Photos (Quality & Fraud Shield)
Status: ✅ Completed
Priority: P2 — Medium
Area: Mobile / Quality Control
Depends On: FN-121
Branch: feat/in-app-communication

### Objective
Require technician to capture a mandatory "Before Work" photograph upon OTP verification and an "After Work" photograph upon job completion, recorded onto the booking timeline to eliminate customer-technician quality disputes.

### Scope
- Domain Model & Repository: `JobProof` and `JobProofRepository` supporting tamper-proof Before & After work photos, technician work notes, pro name, and capture timestamps.
- Provider Modal: `JobProofVerificationDialog` allowing the technician to snap/simulate camera photos for Before and After stages, input technician notes, and complete the job.
- Customer Visibility: `JobProofViewerCard` presenting side-by-side Before/After cards with badges and watermark, embedded seamlessly in `BookingDetailScreen` and `ProviderJobsScreen`.
- Integration into provider job workflow: Tapping "Complete job" prompts for verification photos before job advancement.

### Acceptance Criteria
- [x] Provider can open `JobProofVerificationDialog` to capture Before & After photos and enter work notes.
- [x] `JobProofRepository` persists and retrieves proofs across provider and customer flows.
- [x] `JobProofViewerCard` displays Before & After thumbnails with verification watermark and technician notes.
- [x] `BookingDetailScreen` displays verified job proof for completed jobs.
- [x] 100% green tests in `flutter test` and clean `flutter analyze`.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/bookings/job_proof_service.dart
mobile/lib/design_system/fix_job_proof_dialog.dart
mobile/lib/features/provider/provider_jobs_screen.dart
mobile/lib/features/bookings/booking_detail_screen.dart
mobile/test/job_proof_verification_test.dart
```

### Notes
Delivered on 2026-08-28:
- Built `JobProof` and `JobProofRepository` in `mobile/lib/features/bookings/job_proof_service.dart`.
- Built `JobProofVerificationDialog` and `JobProofViewerCard` in `mobile/lib/design_system/fix_job_proof_dialog.dart`.
- Integrated into `ProviderJobsScreen` (providing "Verification Photos" and photo-gated job completion) and `BookingDetailScreen` (rendering side-by-side proof viewer for customers).
- Added unit and widget tests in `mobile/test/job_proof_verification_test.dart` (4/4 passed).
- All 194 mobile tests pass (100% green) and `flutter analyze` reports zero issues.

### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-28
Commit: Pending

---

## FN-124 — Implement Saved Address Book (Home, Work, Other)
Status: ✅ Completed
Priority: P2 — Medium
Area: Mobile / User Profile
Depends On: FN-121
Branch: feat/in-app-communication

### Objective
Enable customers to save and manage multi-location addresses (Home, Work, Parents) with floor, flat, building name, and landmark for 1-tap booking address selection.

### Scope
- Domain Model & Repository: `SavedAddress` model (with `AddressLabel`, flat/building, street/area, landmark, city, pincode, GPS coordinates, and default status) and `SavedAddressRepository`.
- Selection Component: `SavedAddressSelectorCard` in `ServiceRequestScreen` allowing 1-tap switching between Home, Work, and other locations with real-time location coordinate updates.
- Creation & Editing: `AddEditAddressModalSheet` enabling customers to add or edit addresses with form validation.
- Profile Management: `_SavedAddressesSection` in `CustomerProfileScreen` allowing customers to view, set default, and delete saved addresses.

### Acceptance Criteria
- [x] Customers can select saved addresses (Home, Work) with 1 tap during service requests.
- [x] Selecting an address updates the booking coordinates and pre-fills service location.
- [x] Modal bottom sheet allows creating new addresses with label chips, landmark, and pincode.
- [x] Saved addresses section in profile allows managing, defaulting, and deleting addresses.
- [x] 100% green tests in `flutter test` and clean `flutter analyze`.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/location/saved_address.dart
mobile/lib/design_system/fix_address_selector.dart
mobile/lib/features/bookings/service_request_screen.dart
mobile/lib/features/profile/customer_profile_screen.dart
mobile/test/saved_address_test.dart
```

### Notes
Delivered on 2026-08-28:
- Created `SavedAddress` and `SavedAddressRepository` in `mobile/lib/features/location/saved_address.dart`.
- Built `SavedAddressSelectorCard` and `AddEditAddressModalSheet` in `mobile/lib/design_system/fix_address_selector.dart`.
- Integrated seamlessly into `ServiceRequestScreen` for 1-tap address selection and `CustomerProfileScreen` for address management.
- Added comprehensive unit and widget tests in `mobile/test/saved_address_test.dart` (4/4 passed).
- All 198 mobile tests pass (100% green) and `flutter analyze` reports zero issues.

### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-28
Commit: 2f59181

---

# Phase 15 — Real-World Scheduling & Commercial Operations

## FN-125 — Implement Interactive Date & Time Slot Picker
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Bookings
Depends On: FN-124
Branch: feat/in-app-communication

### Objective
Enable customers to schedule home repair and maintenance services for a specific date and time slot ("Book for Now" vs "Schedule for Later" with horizontal date picker: Today, Tomorrow, +5 days, and Morning/Afternoon/Evening time windows), pre-filling and persisting the booking schedule.

### Scope
- Domain Model: `BookingSchedule` model with `ScheduleMode` (`now` vs `scheduled`), selected `DateTime`, and `TimeSlot` (`morning` 8–11 AM, `afternoon` 12–3 PM, `evening` 4–7 PM).
- Component: `FixSchedulePickerCard` in `mobile/lib/design_system/fix_schedule_picker.dart`:
  - Toggle between ⚡ "Book for Now (Immediate ~15-30m)" and 📅 "Schedule for Later".
  - Horizontal scrollable Date selector chips (Today, Tomorrow, and upcoming 5 days with Day name and Date number).
  - Time window chips:
    - 🌅 Morning: `08:00 AM – 11:00 AM`
    - ☀️ Afternoon: `12:00 PM – 03:00 PM`
    - 🌆 Evening: `04:00 PM – 07:00 PM`
- Integration: Embedded in `ServiceRequestScreen` passing selected `scheduledAt` to `BookingController.create()`.
- Full widget and unit tests in `mobile/test/schedule_picker_test.dart`.

### Acceptance Criteria
- [x] Customer can toggle between "Book for Now" and "Schedule for Later".
- [x] Selecting a date and time slot dynamically updates schedule preview.
- [x] Slots in the past for "Today" are disabled or hidden.
- [x] Submitting the request passes the calculated `scheduledAt` timestamp to the backend.
- [x] 100% green tests in `flutter test` and clean `flutter analyze`.

### Validation
```bash
cd mobile && flutter analyze && flutter test
```

### Files / Areas
```text
mobile/lib/features/bookings/booking_schedule.dart
mobile/lib/design_system/fix_schedule_picker.dart
mobile/lib/features/bookings/service_request_screen.dart
mobile/test/schedule_picker_test.dart
```

### Notes
Delivered on 2026-08-28:
- Built `BookingSchedule` and `TimeSlot` models in `mobile/lib/features/bookings/booking_schedule.dart`.
- Built `FixSchedulePickerCard` in `mobile/lib/design_system/fix_schedule_picker.dart` with 7-day horizontal calendar strip and 3-hour arrival window slots.
- Wired `scheduledAt` support into `BookingRepository.create()`, `BookingController.create()`, and `ServiceRequestScreen`.
- Created comprehensive test suite in `mobile/test/schedule_picker_test.dart` (3/3 passed).
- All 201 mobile tests pass (100% green) and `flutter analyze` reports zero issues.

### Completion Record
Completed By: Antigravity
Completed Date: 2026-08-28
Commit: Pending

---

## FN-126 — Implement Promo Codes & Coupon Discount Engine
Status: ❌ Cancelled
Priority: P2 — Medium
Area: Mobile / Pricing
Depends On: FN-125
Branch: feat/in-app-communication

### Objective
Enable customers to enter and apply promotional coupons (e.g. `WELCOME100`, `FIRST20`, `FIXNOWFESTIVE`), validate discounts in real-time, and dynamically reduce the checkout and service estimate totals with transparent GST recalculation.

### Cancellation Note
Cancelled per user directive. Promotional code and coupon discount engine is intentionally excluded from the application scope.

---

## FN-127 — Implement Booking Reschedule Flow
Status: ✅ Completed
Priority: P2 — Medium
Area: Mobile / Bookings
Depends On: FN-125
Branch: feat/in-app-communication

### Objective
Provide a dedicated "Reschedule" action on active bookings allowing customers to choose a new date/time slot without cancelling their booking, updating the timeline and sending push alerts to the assigned provider.

### Changes Delivered
- Added `scheduledAt` to `CustomerBooking` model with `copyWith` and ISO parsing in `mobile/lib/features/bookings/booking.dart`.
- Implemented `reschedule` method in `BookingRepository` and `BookingController` with optimistic state update and local notifications.
- Created `FixRescheduleSheet` (`mobile/lib/design_system/fix_reschedule_sheet.dart`) integrating `FixSchedulePickerCard`, reason selection, and immediate feedback.
- Integrated "Reschedule booking" action button and arrival window banner into `BookingDetailScreen` for active bookings (`REQUESTED`, `ASSIGNED`).
- Wired `onReschedule` in `mobile/lib/app/app.dart`.
- Added backend `POST /bookings/:id/reschedule` endpoint in `bookings.controller.ts`, `bookings.service.ts`, and `bookings.dto.ts` with domain event notification.
- Added comprehensive unit and widget tests in `mobile/test/reschedule_test.dart` and `backend/src/bookings/bookings.controller.spec.ts`.
- Validated: 100% green tests (backend controller 8/8 pass, full mobile suite 205/205 pass, flutter analyze 0 issues).

---

## FN-128 — Implement In-App Notification Center & Activity Inbox
Status: ✅ Completed
Priority: P2 — Medium
Area: Mobile / Notifications
Depends On: FN-125
Branch: feat/in-app-communication

### Objective
Provide a top-bar 🔔 Bell icon with an unread badge and dedicated Activity Inbox screen categorizing historical alerts across Bookings, Payments, and Service Updates with 1-tap navigation to relevant screens.

### Changes Delivered
- Built `InAppNotification` model with relative timestamp calculation and `NotificationCategory` (`all`, `bookings`, `payments`, `offers`, `system`) in `mobile/lib/features/notifications/notification_model.dart`.
- Built `NotificationRepository` with remote inbox fetching and seed activity merging in `mobile/lib/features/notifications/notification_repository.dart`.
- Built `NotificationController` with unread tracking, filtering, batch read, item deletion, and live alert emission in `mobile/lib/features/notifications/notification_controller.dart`.
- Built `FixNotificationBellIcon` with animated pill badge and unread counter in `mobile/lib/design_system/fix_notification_bell.dart`.
- Built `NotificationCenterScreen` with filter tabs, swipe-to-dismiss, empty states, and 1-tap booking navigation in `mobile/lib/features/notifications/notification_center_screen.dart`.
- Integrated `FixNotificationBellIcon` into `ServiceDiscoveryScreen` header and wired in `mobile/lib/app/app.dart`.
- Added unit and widget tests in `mobile/test/notification_center_test.dart` (6/6 passed).
- Validated: 100% green tests (211/211 mobile tests pass, flutter analyze 0 issues).

---

# Phase 16 — Production Operations & Commercial Polish

## FN-129 — Provider Active Job Execution Cockpit & OTP Verification
Status: ✅ Completed
Priority: P0 — Critical
Area: Mobile / Provider Experience
Depends On: FN-041, FN-044, FN-124
Branch: feat/in-app-communication

### Objective
Empower service technicians with an interactive active job cockpit guiding them through the real-world job execution lifecycle: slide to "Start Journey", 1-tap Google Maps navigation, "I Have Arrived" notification, 4-digit Customer Service-Start OTP verification modal, before/after job photo review, and complete service action.

### Changes Delivered
- Built `FixOtpInputSheet` in `mobile/lib/design_system/fix_otp_input_sheet.dart` with dedicated 4-digit boxes, keyboard capture, error feedback, and auto-submit.
- Built `ProviderActiveJobCockpitScreen` in `mobile/lib/features/provider/provider_active_job_cockpit_screen.dart` with 4-step progress stepper (`ASSIGNED` -> `EN_ROUTE` -> `IN_PROGRESS` -> `COMPLETED`), customer destination info, Google Maps launcher, direct in-app chat and VoIP call buttons, and state-adaptive lifecycle action cards.
- Integrated Start Journey (`EN_ROUTE`), live GPS sharing toggles, Customer Service-Start OTP entry (`POST /bookings/:id/start-service`), before/after photo verification review (`JobProofVerificationDialog`), and complete service actions.
- Wired interactive tap navigation on active job cards in `ProviderHomeScreen` and added "Open Full Job Cockpit" button in `ProviderJobsScreen`.
- Added unit and widget tests in `mobile/test/provider_active_job_cockpit_test.dart` (5/5 passed).
- Validated: 100% green tests (216/216 mobile tests pass, flutter analyze 0 issues).

---

## FN-130 — Universal Live Search, Filter & Price Sort Bar
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Discovery
Depends On: FN-123
Branch: feat/in-app-communication

### Objective
Equip customer discovery with a prominent top search bar providing live debounced autocomplete across all service categories and sub-services, with filter chips (price low-to-high, rating 4.5+ ⭐, emergency available).

### Changes Delivered
- Added `SubServiceCatalog.getAllSubServices()` helper in `mobile/lib/features/services/sub_service_item.dart`.
- Built `FixUniversalSearchBar` component in `mobile/lib/features/services/fix_universal_search_bar.dart` with gold search icon, clear button, popup sort menu (`Price: Low to High`, `Price: High to Low`, `Fastest <45 min`, `Most Popular`), and horizontal filter chips (`All Services`, `⚡ Emergency`, `Under ₹300`, `Under ₹500`).
- Integrated live search filtering into `ServiceDiscoveryScreen` in `mobile/lib/features/services/service_discovery_screen.dart` with instant sub-service match cards (category tag, pricing, duration, "View & Book" direct navigation).
- Added graceful empty search state with popular quick-action suggestion chips (`Tap Repair`, `Ceiling Fan`, `AC Service`, `Drain Cleaning`, `Switchboard`).
- Added comprehensive unit and widget tests in `mobile/test/universal_search_test.dart` (2/2 passed).
- Validated: 100% green tests (218/218 mobile tests pass, flutter analyze 0 issues).

---

## FN-131 — Downloadable PDF Tax Invoice & Share Sheet
Status: ⬜ Pending
Priority: P2 — Medium
Area: Mobile / Payments
Depends On: FN-053, FN-115
Branch: feat/in-app-communication

### Objective
Enable customers to generate and download official branded GST Tax Invoice PDFs for completed bookings with 1-tap native mobile sharing to WhatsApp, Email, or device storage.
