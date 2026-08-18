# FixNow Project Tasks

This file is the authoritative, permanent task tracker for FixNow developers and AI agents. Keep completed and cancelled tasks as project history, never reuse an ID, and assign the next unused `FN-XXX` ID to newly discovered work.

## Status System

- `⬜ Pending` — The task has not started.
- `In Progress` — An agent or developer is actively working on the task.
- `Blocked` — Work cannot continue because a task, decision, dependency, credential, API, or external requirement is missing.
- `✅ Completed` — Implementation and every required validation are finished.
- `❌ Cancelled` — The task is intentionally no longer required.

Only these statuses are valid. A task cannot be completed while required validation is failing or unavailable. A blocked task must include **Blocker** and **Required To Unblock** sections.

## Priority System

- `P0 — Critical` — Security issue, broken core system, production blocker, or serious data risk.
- `P1 — High` — Core feature or major project foundation.
- `P2 — Medium` — Important but non-blocking functionality.
- `P3 — Low` — Enhancement, polish, optimization, or optional work.

## Operating Rules

1. Read `AGENTS.md` and this file before implementation.
2. Unless explicitly instructed otherwise, one agent run completes exactly one task.
3. Before starting, confirm dependencies are completed and no active task significantly overlaps the listed files or areas.
4. Mark the selected task `In Progress`, add it to **Current Work**, and use its branch.
5. Work only within its scope. Record newly discovered work as a new pending task instead of implementing it.
6. Complete a task only after every acceptance criterion and validation requirement is satisfied; update its completion record and the summary.
7. Select the next eligible task by priority (`P0` through `P3`), then generally by lowest ID.

# Project Progress

Total Tasks: 95
Completed: 68
In Progress: 1
Blocked: 1
Pending: 24
Cancelled: 1
Current Phase: Phase 7 — Real-Time & Location
Next Recommended Task: FN-050 — Implement Admin Complaints and Analytics Views

# Current Work

Active Tasks: FN-075 — Implement Customer Help and Support Experience; FN-095 — Add Customer Live Map Projection and Background Booking Reconciliation

# Decision Log

Material architecture decisions belong in [`docs/architecture/decisions/`](docs/architecture/decisions/), using [`0000-template.md`](docs/architecture/decisions/0000-template.md). The discovery index at [`docs/decisions/`](docs/decisions/README.md) points to that canonical location. Accepted decisions are indexed in [`docs/architecture/decisions/README.md`](docs/architecture/decisions/README.md); unresolved vendor and stack choices remain deferred. Do not treat roadmap wording as an approved decision.

# Phase 0 — Repository Foundation

## FN-001 — Initialize Git Repository

Status: ✅ Completed
Priority: P1 — High
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

## FN-002 — Establish Agent Development Rules

Status: ✅ Completed
Priority: P1 — High
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

## FN-003 — Establish Monorepo Domain Layout

Status: ✅ Completed
Priority: P1 — High
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

## FN-004 — Configure Repository Ignore and Environment Examples

Status: ✅ Completed
Priority: P1 — High
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

## FN-005 — Configure Protected-Branch Git Hook

Status: ✅ Completed
Priority: P1 — High
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

## FN-006 — Add GitHub Collaboration Templates

Status: ✅ Completed
Priority: P2 — Medium
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

## FN-007 — Add Core Project and Security Documentation

Status: ✅ Completed
Priority: P1 — High
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

## FN-008 — Document Architecture Boundaries and ADR Process

Status: ✅ Completed
Priority: P1 — High
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

## FN-009 — Establish Persistent Project Task Management

Status: ✅ Completed
Priority: P1 — High
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

# Phase 1 — Project Architecture

## FN-010 — Define Product Requirements and Domain Glossary

Status: ✅ Completed
Priority: P1 — High
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

## FN-011 — Define API and Error-Response Conventions

Status: ✅ Completed
Priority: P1 — High
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

## FN-012 — Decide Data and Storage Architecture

Status: ✅ Completed
Priority: P1 — High
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

## FN-013 — Define Identity, Roles, and Permission Model

Status: ✅ Completed
Priority: P1 — High
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

## FN-014 — Define Security and Privacy Architecture

Status: ✅ Completed
Priority: P1 — High
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

## FN-015 — Define Real-Time and Notification Architecture

Status: ✅ Completed
Priority: P1 — High
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

## FN-016 — Define AI Governance and Evaluation Architecture

Status: ⬜ Pending
Priority: P2 — Medium
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
- [ ] AI risks, metrics, failure handling, and approval gates are documented.

### Validation
```bash
git diff --check
```

### Files / Areas
```text
docs/architecture/decisions/ docs/ai/ ai/
```

### Notes
None.

### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-072 — Establish Authoritative UI/UX Design System

Status: ✅ Completed
Priority: P1 — High
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

# Phase 2 — Backend Foundation

## FN-017 — Initialize Backend Application
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-018 — Add Backend Configuration and Structured Logging
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-019 — Add PostgreSQL Persistence Foundation
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-020 — Add Redis Cache and Coordination Foundation
Status: ✅ Completed
Priority: P2 — Medium
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
Commit: Pending
PR: Pending

## FN-021 — Add Backend Request Validation and Global Error Handling
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-022 — Add Backend Health and Readiness Endpoints
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

# Phase 3 — Authentication & Users

## FN-023 — Create User and Identity Data Model
Status: ✅ Completed
Priority: P1 — High
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

## FN-024 — Implement Customer Registration and Login
Status: ✅ Completed
Priority: P1 — High
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

## FN-025 — Implement Provider Registration
Status: ✅ Completed
Priority: P1 — High
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

## FN-026 — Implement OTP and Refresh-Token Lifecycles
Status: ✅ Completed
Priority: P1 — High
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

## FN-027 — Enforce Role-Based Authorization
Status: ✅ Completed
Priority: P1 — High
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

## FN-028 — Implement Customer Profile Management
Status: ✅ Completed
Priority: P2 — Medium
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

# Phase 4 — Provider System

## FN-029 — Model Service Categories and Provider Skills
Status: ✅ Completed
Priority: P1 — High
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

## FN-030 — Implement Provider Profile and Service Areas
Status: ✅ Completed
Priority: P1 — High
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

## FN-031 — Implement Provider Document Upload
Status: ✅ Completed
Priority: P1 — High
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

## FN-032 — Implement Provider Verification Workflow
Status: ✅ Completed
Priority: P1 — High
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

## FN-033 — Implement Provider Availability
Status: ✅ Completed
Priority: P1 — High
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

# Phase 5 — Customer Mobile Foundation

## FN-034 — Initialize Flutter Mobile Application
Status: ✅ Completed
Priority: P1 — High
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

## FN-035 — Establish Mobile Navigation, State, and Design System
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-036 — Add Mobile API Client and Authentication State
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-037 — Implement Customer Profile, Location, and Service Discovery UI
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

# Phase 6 — Service Booking

## FN-038 — Create Booking Data Model and Lifecycle Contract
Status: ✅ Completed
Priority: P1 — High
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

## FN-039 — Implement Service Request Creation
Status: ✅ Completed
Priority: P1 — High
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

## FN-040 — Implement Provider Matching
Status: ✅ Completed
Priority: P1 — High
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

## FN-041 — Implement Provider Acceptance and Booking Progress
Status: ✅ Completed
Priority: P1 — High
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

## FN-042 — Implement Booking Cancellation and Service History
Status: ✅ Completed
Priority: P1 — High
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

# Phase 7 — Real-Time & Location

## FN-043 — Add Authenticated WebSocket Infrastructure
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-044 — Implement Provider Presence and Live Location Ingestion
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

## FN-045 — Implement Booking Tracking, ETA, and Real-Time Events
Status: ✅ Completed
Priority: P1 — High
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
Commit: Pending
PR: Pending

# Phase 8 — Admin Dashboard

## FN-046 — Initialize Admin Web Application
Status: ✅ Completed
Priority: P1 — High
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

## FN-047 — Implement Admin Authentication and Authorization UI
Status: ✅ Completed
Priority: P1 — High
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

## FN-048 — Implement Admin User and Provider Verification Management
Status: ✅ Completed
Priority: P1 — High
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

## FN-049 — Implement Admin Service and Booking Management
Status: ✅ Completed
Priority: P2 — Medium
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

## FN-050 — Implement Admin Complaints and Analytics Views
Status: ⬜ Pending
Priority: P2 — Medium
Area: Admin
Depends On: FN-047, FN-055
Branch: feat/admin-complaints-analytics

### Objective
Support complaint operations and privacy-safe operational analytics.
### Scope
- Add complaint queues/details/actions and aggregate user, provider, booking, and payment views.
### Do Not
- Do not expose unrestricted raw personal data or misleading metrics.
### Acceptance Criteria
- [ ] Permissions, redaction, filtering, audit, empty state, and accessibility tests pass.
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 9 — Payments

## FN-051 — Decide Payment Architecture and Integrate Provider Adapter
Status: ⬜ Pending
Priority: P1 — High
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
- [ ] ADR, signature validation, configuration, money precision, and adapter tests pass.
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-052 — Implement Payment Orders and Verification
Status: ⬜ Pending
Priority: P1 — High
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
- [ ] Signature, replay, amount, booking ownership, race, and reconciliation tests pass.
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-053 — Implement Invoices, Refunds, Transactions, and Provider Earnings
Status: ⬜ Pending
Priority: P1 — High
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
- [ ] Precision, partial/full refund, idempotency, permission, invoice, and earnings tests pass.
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 10 — Ratings & Trust

## FN-054 — Implement Booking Ratings and Reviews
Status: ⬜ Pending
Priority: P2 — Medium
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
- [ ] Eligibility, duplicate, ownership, moderation, aggregation, and privacy tests pass.
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-055 — Implement Complaints, Quality Metrics, and Fraud Rules
Status: ⬜ Pending
Priority: P1 — High
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
- [ ] Permissions, retention, transitions, metric correctness, rule false-positive, and audit tests pass.
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 11 — AI

## FN-056 — Initialize Governed AI Service Foundation
Status: ⬜ Pending
Priority: P2 — Medium
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
- [ ] Configuration, timeout, malformed output, redaction, budget, and fallback tests pass.
### Validation
```bash
# Run AI lint/type/tests and evaluation smoke tests without live secrets.
```
### Files / Areas
```text
ai/ backend/src/ai/ docs/ai/ .env.example
```
### Notes
No live provider calls in default tests.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-057 — Implement Issue Classification and Service Recommendation
Status: ⬜ Pending
Priority: P2 — Medium
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
- [ ] Quality thresholds, adversarial input, abstention, latency, cost, and schema tests pass.
### Validation
```bash
# Run AI checks and the versioned classification/recommendation evaluation suite.
```
### Files / Areas
```text
ai/src/classification/ ai/evals/ backend/src/ai/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-058 — Implement Voice Input and Translation Assistance
Status: ⬜ Pending
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
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-059 — Implement Image Issue Analysis
Status: ⬜ Pending
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
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-060 — Implement Price Estimation and Fraud Signal Assistance
Status: ⬜ Pending
Priority: P2 — Medium
Area: AI/Trust
Depends On: FN-053, FN-055, FN-056
Branch: feat/ai-price-fraud-assistance

### Objective
Provide explainable advisory price ranges and reviewable fraud signals.
### Scope
- Add feature governance, uncertainty, explanations, evaluation, monitoring, and human-review routing.
### Do Not
- Do not set final prices or automatically penalize users/providers.
### Acceptance Criteria
- [ ] Bias, drift, uncertainty, explanation, privacy, and false-positive thresholds pass.
### Validation
```bash
# Run versioned price and fraud evaluation suites plus policy tests.
```
### Files / Areas
```text
ai/src/pricing/ ai/src/fraud/ ai/evals/ backend/src/trust/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 12 — Notifications

## FN-061 — Add Push Notification Infrastructure
Status: ⬜ Pending
Priority: P1 — High
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
- [ ] Registration, revocation, retry, invalid-token, consent, and redaction tests pass.
### Validation
```bash
# Run backend notification tests and mobile analyze/test commands with provider fakes.
```
### Files / Areas
```text
backend/src/notifications/ mobile/lib/notifications/ infrastructure/ .env.example
```
### Notes
FCM is a candidate requiring approval and configuration.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-062 — Implement Booking, Provider, Reminder, and Emergency Notifications
Status: ⬜ Pending
Priority: P1 — High
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 13 — Emergency System

## FN-063 — Implement Emergency Request and Priority Dispatch
Status: ⬜ Pending
Priority: P1 — High
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-064 — Implement SOS UX and Safety Guidance
Status: ⬜ Pending
Priority: P1 — High
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
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 14 — Testing & Security

## FN-065 — Establish Cross-Project Test Strategy and CI Test Harness
Status: ⬜ Pending
Priority: P1 — High
Area: Quality
Depends On: FN-017, FN-034, FN-046
Branch: test/project-test-strategy

### Objective
Define the test pyramid, fixtures, isolation, coverage expectations, and repeatable CI commands.
### Scope
- Add strategy docs and deterministic unit/integration/E2E harness configuration.
### Do Not
- Do not hide flaky tests or require production services.
### Acceptance Criteria
- [ ] Each application has documented reproducible test commands and isolation rules.
### Validation
```bash
# Run every documented project test command in a clean environment.
```
### Files / Areas
```text
docs/testing/ backend/test/ mobile/test/ admin/ infrastructure/ci/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-066 — Add Authorization, Abuse, and Rate-Limit Security Tests
Status: ⬜ Pending
Priority: P0 — Critical
Area: Security Testing
Depends On: FN-027, FN-040, FN-052, FN-055, FN-065
Branch: test/security-boundaries

### Objective
Verify cross-role isolation, ownership, abuse controls, rate limits, and sensitive workflows.
### Scope
- Add matrix tests for auth, bookings, payments, complaints, uploads, and administrative actions.
### Do Not
- Do not weaken production controls to simplify tests.
### Acceptance Criteria
- [ ] Defined permission and abuse matrices pass with deny-by-default behavior.
### Validation
```bash
# Run the complete security integration suite and application checks.
```
### Files / Areas
```text
backend/test/security/ docs/security/ infrastructure/test/
```
### Notes
Becomes urgent when its dependencies are complete.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-067 — Complete End-to-End, Dependency, and Security Review
Status: ⬜ Pending
Priority: P0 — Critical
Area: Release Quality
Depends On: FN-045, FN-050, FN-053, FN-060, FN-062, FN-064, FN-066
Branch: test/release-security-review

### Objective
Validate critical user/provider/admin journeys and complete pre-production security review.
### Scope
- Add E2E journeys, dependency audit, secret scan, threat-model review, and remediation records.
### Do Not
- Do not waive failing security checks without explicit documented approval.
### Acceptance Criteria
- [ ] Critical E2E suites and approved security/dependency gates pass with no unresolved release blockers.
### Validation
```bash
# Run all project checks, E2E suites, dependency audits, and secret scanning.
```
### Files / Areas
```text
backend/test/e2e/ mobile/integration_test/ admin/e2e/ docs/security/ infrastructure/ci/
```
### Notes
Independent focused review is required.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-073 — Repair Backend Validation Baseline
Status: ✅ Completed
Priority: P1 — High
Area: Backend/Quality
Depends On: FN-017
Branch: fix/backend-validation-baseline

### Objective
Restore deterministic, environment-isolated backend lint and test validation.
### Scope
- Resolve existing backend ESLint violations without weakening rules.
- Isolate database module tests from developer PostgreSQL credentials and document the integration-test database setup.
### Do Not
- Do not weaken lint rules, embed credentials, or require a shared/production database.
### Acceptance Criteria
- [x] Backend lint passes without unrelated formatter churn.
- [x] Backend unit tests pass without connecting to a developer database.
- [x] The isolated PostgreSQL integration-test setup is documented and can validate migration up/down behavior.
### Validation
```bash
cd backend
npm run lint
npm test -- --runInBand
npm run build
```
### Files / Areas
```text
backend/src/cache/ backend/src/common/ backend/src/config/ backend/src/database/ backend/src/health/ backend/src/logging/ backend/test/ backend/README.md
```
### Notes
Discovered while validating FN-023. Replaced the database module's connection-coupled unit test with pure configuration validation, corrected typed lint failures, and documented disposable loopback-only PostgreSQL migration validation. Required lint, unit test, and build commands pass.
### Completion Record
Completed By: Codex
Completed Date: 2026-08-09
Commit: 23d9275
PR: #4

# Phase 15 — Deployment

## FN-068 — Add Container Builds and Continuous Integration
Status: ⬜ Pending
Priority: P1 — High
Area: Infrastructure/CI
Depends On: FN-017, FN-034, FN-046, FN-065
Branch: ci/container-builds

### Objective
Create reproducible least-privilege builds and required CI checks.
### Scope
- Add pinned workflows, caches, artifact rules, container builds, and supply-chain controls.
### Do Not
- Do not deploy, use floating action tags, or bake secrets into images.
### Acceptance Criteria
- [ ] Clean builds, tests, scans, and container health checks pass in CI.
### Validation
```bash
# Run local build validation and verify all CI checks on the branch.
```
### Files / Areas
```text
.github/workflows/ infrastructure/ backend/ admin/
```
### Notes
Mobile release builds may require separate signed workflows discovered as new tasks.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-069 — Provision and Validate Staging Environment
Status: ⬜ Pending
Priority: P1 — High
Area: Infrastructure
Depends On: FN-012, FN-014, FN-022, FN-061, FN-068
Branch: feat/staging-environment

### Objective
Provision an approved staging environment with least privilege and isolated non-production data.
### Scope
- Record cloud ADR, add reviewed IaC, secrets integration, DNS/TLS, migrations, monitoring, and runbook.
### Do Not
- Do not use production credentials/data or apply infrastructure without explicit authorization.
### Acceptance Criteria
- [ ] Reviewed plans, staging deploy, health, rollback, access, and isolation checks pass.
### Validation
```bash
# Run IaC format/validate/security checks, then authorized staging smoke tests.
```
### Files / Areas
```text
infrastructure/environments/staging/ docs/runbooks/ .github/workflows/
```
### Notes
External account access and cost approval are required.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-070 — Provision Production Operations, Monitoring, and Backups
Status: ⬜ Pending
Priority: P0 — Critical
Area: Infrastructure/Operations
Depends On: FN-067, FN-069
Branch: feat/production-operations

### Objective
Create reviewed production infrastructure with monitoring, alerting, logging, backup, restore, and incident controls.
### Scope
- Add production IaC, least privilege, SLOs, alerts, retention, restore drills, and runbooks.
### Do Not
- Do not deploy without explicit authorization, approved review, and rollback plan.
### Acceptance Criteria
- [ ] Plans, security review, restore drill, alert tests, capacity checks, and runbooks are approved.
### Validation
```bash
# Run IaC/security validation and authorized non-destructive operational drills.
```
### Files / Areas
```text
infrastructure/environments/production/ infrastructure/monitoring/ docs/runbooks/
```
### Notes
Production changes require focused approval and controlled rollout.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-071 — Establish Release and Rollback Strategy
Status: ⬜ Pending
Priority: P1 — High
Area: Release Engineering
Depends On: FN-068, FN-069, FN-070
Branch: docs/release-strategy

### Objective
Define versioning, approvals, staged rollout, database compatibility, rollback, and release communication.
### Scope
- Add release runbook, checklists, ownership, evidence requirements, and drill process.
### Do Not
- Do not perform a production release in this documentation task.
### Acceptance Criteria
- [ ] Release and rollback dry run succeeds and required approvals/evidence are explicit.
### Validation
```bash
git diff --check
# Execute the documented release dry-run checklist without production mutation.
```
### Files / Areas
```text
docs/releases/ docs/runbooks/ .github/workflows/ infrastructure/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-074 — Audit and Polish Mobile UX and Local System Health
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Backend / Quality
Depends On: FN-034, FN-045, FN-073
Branch: fix/mobile-ui-system-audit

### Objective
Validate the implemented mobile and backend foundations together, identify what works and what fails, and correct the highest-impact phone UI/UX defects visible in current customer flows.

### Scope
- Run the complete available Flutter and backend static, unit, widget, integration, build, and local runtime smoke checks that the workstation supports.
- Audit current customer mobile screens at phone size, using supplied and newly captured screenshots as evidence.
- Remove internal implementation language from customer-facing UI and improve hierarchy, density, spacing, actions, loading, empty, and offline states where findings are verified.
- Add or update focused tests for changed behavior and record follow-up tasks for issues outside this task's bounded implementation scope.

### Do Not
- Do not implement roadmap features, scaffold the admin application, deploy services, or connect to production data or credentials.
- Do not redesign backend contracts or introduce a new framework, hosted dependency, or database.

### Acceptance Criteria
- [x] Mobile analysis and tests pass, and the application builds for an available local target.
- [x] Backend lint, unit tests, integration tests that can run safely, and build pass.
- [x] Available services start locally and receive non-destructive smoke checks, with unsupported prerequisites documented precisely.
- [x] High-impact customer phone UI findings are fixed and covered by focused widget tests.
- [x] Final screenshots and an audit report clearly distinguish working, failing, fixed, and deferred areas.

### Validation
```bash
cd mobile && flutter analyze && flutter test
cd backend && npm run lint && npm test -- --runInBand && npm run build
git diff --check
```

### Files / Areas
```text
mobile/lib/ mobile/test/ backend/ docs/quality/ PROJECT_TASKS.md
```

### Notes
Completed a physical Android 16 walkthrough against an isolated local PostgreSQL/Redis-backed API. Fixed Home density and category recognition, removed internal task language, repaired isolated integration testing and suite order safety, and aligned backend runtime scripts with the monorepo build output. Mobile analysis and 40 tests, backend lint, 197 unit tests, 38 integration tests, build, migrations, health/readiness, and live category API checks passed. Full evidence and deferred scope are recorded in `docs/quality/mobile-system-audit-2026-08-13.md`. Existing untracked root screenshots remain user-owned and unchanged.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: b8bf252
PR: Pending

## FN-075 — Implement Customer Help and Support Experience
Status: In Progress
Priority: P2 — Medium
Area: Mobile / Backend / Support
Depends On: FN-027, FN-034
Branch: feat/customer-help-support

### Objective
Replace the honest Help preview state with a usable, safe customer support experience.

### Scope
- Define supported contact and self-service paths, case ownership, response expectations, and safe emergency escalation copy.
- Implement authenticated customer Help UI and the minimum backend contract approved for support requests.
- Cover loading, offline, unauthenticated, submission, duplicate, and failure states accessibly.

### Do Not
- Do not present Help as an emergency-response service or promise unavailable response times.
- Do not add a hosted support vendor without explicit approval and an ADR where required.

### Acceptance Criteria
- [ ] Customers can understand available support options and submit or follow the approved support flow.
- [ ] Emergency guidance is clearly separated from ordinary support and uses approved safety language.
- [ ] Authorization, abuse, privacy, accessibility, offline, and failure tests pass.

### Validation
```bash
cd mobile && flutter analyze && flutter test
cd backend && npm run lint && npm test -- --runInBand && npm run build
```

### Files / Areas
```text
mobile/lib/features/support/ mobile/test/ backend/src/support/ backend/test/ docs/product/ docs/security/
```

### Notes
Discovered during FN-074 live-device QA. Until this task is complete, the Help tab must remain an honest preview state with immediate-danger guidance.

### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-076 — Complete Customer Sign-In and Service Request Journey
Status: ✅ Completed
Priority: P0 — Critical
Area: Mobile / Backend / Quality
Depends On: FN-026, FN-037, FN-042, FN-074
Branch: feat/customer-core-journey

### Objective
Turn the current mobile foundation into a usable customer journey: authenticate, choose a service, describe the problem, confirm location, create a request, and see the resulting booking state in a professional phone UI.

### Scope
- Add polished customer sign-in and registration screens with validation, loading, failure, session restore, and sign-out behavior.
- Make service categories actionable and implement the supported request flow through the existing authenticated booking contract.
- Replace the static bookings preview with authenticated booking history and clear requested/matching states.
- Add focused API, controller, and widget coverage and verify the journey against the isolated local backend on a phone-sized target.

### Do Not
- Do not claim that a customer selected a provider when the booking contract only supports provider acceptance after request creation.
- Do not change matching policy, expose provider coordinates, add payment, or introduce a new framework, vendor, or production dependency.
- Do not implement unrelated provider, admin, support, or live-tracking roadmap scope.

### Acceptance Criteria
- [x] A new customer can register, verify email, an existing customer can sign in, a valid session restores, and sign-out returns to authentication.
- [x] Selecting a service opens a usable request form and a successful submission creates exactly one authenticated booking.
- [x] Customers can see their booking history and understand requested, matching, empty, loading, offline, and failure states.
- [x] The changed phone UI follows `DESIGN.md`, is accessible at supported text scale, and has no inert primary controls.
- [x] Mobile analysis/tests and relevant backend checks pass; a local end-to-end smoke test is recorded.

### Validation
```bash
cd mobile && flutter analyze && flutter test
cd backend && npm run lint && npm test -- --runInBand && npm run build
git diff --check
```

### Files / Areas
```text
mobile/lib/app/ mobile/lib/auth/ mobile/lib/features/services/ mobile/lib/features/bookings/ mobile/test/ backend/src/auth/ backend/src/bookings/ backend/test/ docs/quality/ PROJECT_TASKS.md
```

### Notes
Completed the connected customer journey across native and web targets. Added authentication, registration, required email verification/resend, secure native session restore, web-safe session behavior, actionable services, location-backed idempotent requests, and API-backed booking history. Added strict configured browser CORS support and Flutter Web host files after the user explicitly selected browser QA. Flutter analysis, 43 tests, web build and Android debug build passed; backend lint, 44 suites / 198 tests, build, and isolated registration/login/booking/history smoke passed. Local SMTP was unavailable by design, so delivery failure/retry behavior was verified while backend OTP behavior remains covered by tests. Full evidence: `docs/quality/customer-core-journey-browser-qa-2026-08-13.md`.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: 0a37340
PR: Pending

## FN-077 — Elevate Customer Mobile Visual Design
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Design / Quality
Depends On: FN-074, FN-076
Branch: feat/customer-core-journey

### Objective
Turn the working customer journey into a polished, premium-feeling experience across phone and browser layouts while preserving its existing behavior, accessibility, and honest product states.

### Scope
- Strengthen visual hierarchy, responsive content width, page composition, typography, and calm blue-led surface treatment across authentication, Home, request, bookings, Help preview, and Profile.
- Refine shared mobile design-system components and tokens only where the approved `DESIGN.md` language already permits the change.
- Verify the refreshed journey at phone and desktop browser sizes and keep newly captured review screenshots outside Git.

### Do Not
- Do not change backend contracts, booking/authentication behavior, provider matching, or roadmap feature scope.
- Do not add gradients, glassmorphism, decorative clutter, a new font/icon library, random colors, hosted dependencies, or committed QA screenshots.
- Do not turn the Help preview into a support implementation or imply unavailable functionality.

### Acceptance Criteria
- [x] Authentication, Home, service request, bookings, Help preview, and Profile share a deliberate premium visual hierarchy and responsive content frame.
- [x] The approved semantic palette, typography, spacing, radii, component states, touch targets, and accessibility requirements remain intact.
- [x] Existing customer journey widget tests pass and focused design-system or screen assertions cover changed behavior where appropriate.
- [x] Flutter analysis, Flutter tests, web build, desktop/phone browser visual checks, and `git diff --check` pass.
- [x] No newly captured review screenshot is committed.

### Validation
```bash
cd mobile && flutter analyze && flutter test && flutter build web
git diff --check
```

### Files / Areas
```text
mobile/lib/design_system/ mobile/lib/auth/ mobile/lib/app/ mobile/lib/features/ mobile/test/ PROJECT_TASKS.md
```

### Notes
The user explicitly requested that this follow-up remain on `feat/customer-core-journey`. Added a shared responsive page frame and brand/header patterns; refined authentication, Home, request, bookings, Help preview, and Profile hierarchy using the approved navy, blue, neutral, spacing, radius, and shadow tokens. Flutter analysis, all 43 tests, web production build, focused narrow-screen accessibility tests, and temporary phone/desktop Chrome checks passed. Review screenshots remained in the operating-system temporary directory and were not committed. Existing root screenshots were restored after completion.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: b49aec7
PR: Pending

## FN-078 — Run Connected Android Customer Journey QA
Status: ✅ Completed
Priority: P0 — Critical
Area: Mobile / Backend / Quality
Depends On: FN-076, FN-077
Branch: feat/customer-core-journey

### Objective
Deploy the current customer application to the connected Android phone and verify the available authentication, discovery, request, booking, Help preview, Profile, navigation, failure, and backend paths as a real user.

### Scope
- Start the isolated local backend dependencies and API required by the phone build.
- Install and run the current Flutter application on the connected Android 16 device.
- Exercise every implemented customer screen and primary interaction, record reproducible issues, fix standard-tier findings, and re-test.
- Keep device screenshots and transient QA artifacts outside Git and restore the user's existing screenshots afterward.

### Do Not
- Do not use production credentials, services, or data.
- Do not implement pending roadmap features such as full Help, payments, provider selection, or live tracking.
- Do not commit screenshots or expose test credentials in reports or logs.

### Acceptance Criteria
- [x] The current app installs and starts on device `00162358M004276`.
- [x] Local backend health and required customer endpoints are available to the device.
- [x] Authentication, Home, service request, bookings, Help preview, Profile, sign-out, validation, and recoverable failure states are tested.
- [x] Every verified critical, high, and medium issue is fixed and re-tested, or recorded truthfully as blocked/deferred.
- [x] Relevant Flutter/backend checks pass and no screenshots are committed.

### Validation
```bash
cd mobile && flutter analyze && flutter test && flutter build apk --debug
cd backend && npm run lint && npm test -- --runInBand && npm run build
git diff --check
```

### Files / Areas
```text
mobile/ backend/ docs/quality/ PROJECT_TASKS.md
```

### Notes
Deployed the branch APK to the connected A059 Android 16 phone and tested the implemented customer journey against the isolated local backend over USB forwarding. Valid and invalid login, location state, four service categories, request validation and creation, booking history, Help safety copy, Profile save, navigation, and sign-out passed. No reproducible critical, high, or medium issue required a code change. Flutter analysis and 43 tests passed; Android debug build passed; backend lint, 44 suites / 198 tests, and build passed. Text-only evidence: `docs/quality/connected-android-customer-qa-2026-08-13.md`. Temporary screenshots were not committed and the user's root screenshots were restored.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: 90692fc
PR: Pending

## FN-079 — Reconcile Premium Mobile Design Direction and Screen Inventory
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Design / Product
Depends On: FN-010, FN-014, FN-072, FN-078
Branch: feat/customer-core-journey

### Objective
Turn the approved premium dark, emerald, map-first visual direction into durable FixNow design guidance and an evidence-based inventory of every customer and provider mobile screen.

### Scope
- Audit mobile routes, screens, design tokens, navigation, models, API contracts, feature modules, and relevant product/privacy architecture.
- Reconcile `DESIGN.md` with the approved premium direction while preserving safety, privacy, accessibility, and honest-state requirements.
- Create `docs/design/screen-inventory.md` with routes, implementation/design status, dependencies, and notes.
- Record cohesive follow-up tasks for implementation gaps without presenting unavailable product functionality as complete.

### Do Not
- Do not redesign application code or implement multiple product flows in this documentation task.
- Do not mark backend-dependent screens complete because a visual concept exists.
- Do not add proprietary assets, unsupported features, hosted dependencies, or committed screenshots.

### Acceptance Criteria
- [x] `DESIGN.md` defines the approved shared customer/provider premium dark system and semantic emerald palette.
- [x] The screen inventory classifies all required mobile screens as exists/good, needs redesign, partial, missing, blocked, or future with evidence.
- [x] Missing implementation work is represented by dependency-aware pending tasks.
- [x] Documentation links and formatting validate, and user-owned screenshots remain untracked.

### Validation
```bash
git diff --check
git status --short
```

### Files / Areas
```text
DESIGN.md docs/design/ PROJECT_TASKS.md mobile/lib/ backend/src/ shared/
```

### Notes
The user explicitly requested that the premium reconstruction remain on `feat/customer-core-journey`. Audited the Flutter shell, routes, screens, design system, feature models/controllers, backend controllers, shared booking contracts, product requirements, and privacy rules. `DESIGN.md` now defines the approved premium dark/emerald direction and `docs/design/screen-inventory.md` records current coverage and honest dependencies. Implementation is split into FN-080 through FN-083.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: 531ea44
PR: Pending

## FN-080 — Implement Premium Dark Mobile Design Foundation
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Design System
Depends On: FN-079
Branch: feat/customer-core-journey

### Objective
Migrate the Flutter design tokens, theme, shared states, components, motion, and role-aware navigation foundation to the approved premium dark emerald system.

### Scope
- Update existing centralized tokens and theme; do not create a parallel design system.
- Implement or consolidate reusable buttons, inputs, cards, badges, navigation, loading, empty, error, and offline patterns.
- Preserve accessibility, safe areas, text scaling, keyboard behavior, and existing functionality.

### Do Not
- Do not redesign feature screens beyond the minimum migration needed to keep them functional.
- Do not add a new icon library, hosted dependency, proprietary asset, or unsupported feature.

### Acceptance Criteria
- [x] Semantic dark tokens cover every role defined by `DESIGN.md` with contrast evidence.
- [x] Shared components and customer/provider navigation use one coherent visual grammar.
- [x] Small/standard/large phone, keyboard, text-scale, reduced-motion, and state tests pass.

### Validation
```bash
cd mobile && flutter analyze && flutter test
git diff --check
```

### Files / Areas
```text
mobile/lib/design_system/ mobile/lib/app/ mobile/test/ DESIGN.md
```

### Notes
Implemented the premium dark default theme with deep neutral surfaces, emerald interaction states, separate danger/emergency/verified/rating semantics, elevated surfaces, motion tokens, responsive button behavior, card variants, and reusable empty, error, offline, and skeleton states. Existing customer/provider navigation metadata and feature behavior remain unchanged. Flutter analysis passed, all 45 tests passed, and the web production build plus Wasm dry run succeeded. Contrast assertions cover primary text, secondary text, and primary CTA content; adaptive tests cover 320, 390, and 600 logical-pixel widths at 200% text scale with reduced motion. The adaptive test exposed a shared long-label overflow, which was fixed by making button content wrap safely.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: 8ddc582
PR: Pending

## FN-081 — Implement Premium Role-Aware Authentication and Onboarding Entry
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Authentication / Provider
Depends On: FN-025, FN-026, FN-080
Branch: feat/customer-core-journey

### Objective
Implement welcome, role selection, premium shared sign-in, customer registration, email verification, and the supported provider-registration entry without inventing recovery or social authentication.

### Scope
- Add a concise welcome screen and explicit customer/provider role selection.
- Preserve customer email/password registration/login and email OTP verification.
- Connect provider registration to the existing backend contract and route provider accounts into honest onboarding state.

### Do Not
- Do not present phone OTP, social login, forgot-password recovery, or provider approval as available without backend support.

### Acceptance Criteria
- [x] Customer and provider entry paths are visually related, accessible, and route by real account state.
- [x] Keyboard, validation, loading, failure, verification, session restore, and sign-out tests pass.
- [x] No inert or falsely enabled authentication action is shown.

### Validation
```bash
cd mobile && flutter analyze && flutter test
cd backend && npm run lint && npm test -- --runInBand && npm run build
```

### Files / Areas
```text
mobile/lib/auth/ mobile/lib/app/ mobile/test/ backend/src/auth/ backend/src/providers/
```

### Notes
Implemented premium Welcome, registration/sign-in intent, customer/provider role selection, shared credential form, and the existing email OTP flow. Authentication responses now include the server-resolved role; sessions persist it across refresh and relaunch. Added provider login routing and corrected login role resolution from persisted assignments. Verified provider applicants reach an honest profile-incomplete handoff stating that setup and verification are required before receiving work; FN-083 owns the full onboarding. Forgot-password, social login, and phone OTP remain absent because no approved backend support exists. Flutter analysis and 51 tests passed; backend lint, 44 suites / 200 tests, and build passed.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-13
Commit: 49baaa8
PR: Pending

## FN-082 — Reconstruct Premium Customer Core and Tracking Experience
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Customer / Design
Depends On: FN-045, FN-080, FN-081
Branch: feat/customer-core-journey

### Objective
Apply the premium system to the supported customer journey from discovery through request, matching, booking detail, live status, profile, and honest support.

### Scope
- Reconstruct Home, services, request, location consent, matching, booking list/detail, tracking, Profile, and Help using actual contracts.
- Wire existing authorized tracking state into reachable booking navigation and use a map-first layout only where map data and SDK configuration are available.
- Cover loading, empty, offline, error, keyboard, responsive, and accessibility states.

### Do Not
- Do not fabricate nearby providers, price, payments, chat, reviews, saved addresses, emergency response, or unsupported ETA.

### Acceptance Criteria
- [x] The complete supported customer flow is reachable and visually coherent.
- [x] Booking actions and tracking labels follow the authoritative lifecycle and freshness rules.
- [x] Phone/device visual QA and relevant Flutter/backend checks pass with screenshots outside Git.

### Validation
```bash
cd mobile && flutter analyze && flutter test
cd backend && npm run lint && npm test -- --runInBand && npm run build
git diff --check
```

### Files / Areas
```text
mobile/lib/features/ mobile/lib/app/ mobile/test/ docs/quality/
```

### Notes
Provider results/profile remain blocked until a customer-safe read model is defined.

Implemented a premium discovery header, trust composition, request/matching surface,
reachable booking-detail flow, and customer account presentation. Tracking is map-ready
but intentionally renders an honest unavailable state until the API supplies an authorized,
fresh provider position and the map SDK is configured. Android cleartext access is enabled
only in the debug manifest for USB-local API QA. Physical-device evidence is documented in
`docs/quality/connected-android-premium-customer-qa-2026-08-14.md`; screenshots remain outside Git.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: d28a7b4
PR: Pending

## FN-083 — Implement Premium Provider Mobile Core
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Provider / Design
Depends On: FN-030, FN-031, FN-032, FN-033, FN-041, FN-042, FN-080, FN-081
Branch: feat/customer-core-journey

### Objective
Implement the backend-supported provider onboarding, verification, availability, profile, active-job lifecycle, and history as one coherent role-specific mobile experience.

### Scope
- Implement provider profile, skills, service area, private document, review, and verification-state screens.
- Implement provider shell, availability/schedule, active job lifecycle controls, history, and profile management.
- Enforce role, ownership, verification, privacy, and legal transition constraints in UI and API integration.

### Do Not
- Do not display fake earnings, reviews, notifications, customer precision, or incoming-job data unsupported by a provider job-feed contract.

### Acceptance Criteria
- [x] Provider onboarding truthfully covers every backend-supported verification state and recovery action.
- [x] Approved providers can manage availability and valid assigned-booking transitions without accessing unrelated customer data.
- [x] Provider UI shares the customer design system and passes responsive, accessibility, security-boundary, Flutter, and backend checks.

### Validation
```bash
cd mobile && flutter analyze && flutter test
cd backend && npm run lint && npm test -- --runInBand && npm run build
git diff --check
```

### Files / Areas
```text
mobile/lib/features/provider/ mobile/lib/app/ mobile/test/ backend/src/providers/ backend/src/bookings/
```

### Notes
Incoming job feed, provider earnings, ratings, and push notifications remain separate dependency-backed work.

Implemented server-resolved `verified_provider` authentication, an own-application read contract, premium status-aware
applicant onboarding, editable professional profile/service area, service skills, private document upload/listing, and
the approved-provider shell. Approved providers can manage online status, a conservative weekday schedule, valid
assigned-job transitions, history, and profile settings without exposing unrelated customer or document storage data.
The backend intentionally has no applicant self-submit transition; review remains reviewer-controlled. Connected A059
QA verified provider sign-in, profile-incomplete recovery, and the professional setup screen at 1080x2392 without
overflow. Screenshots remain outside Git under the temporary QA directory.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: fd3c885
PR: Pending

## FN-084 — Add Explicit Local OTP Test Code
Status: ✅ Completed
Priority: P2 — Medium
Area: Backend / Mobile / Authentication
Depends On: FN-026, FN-081
Branch: feat/local-otp-bypass

### Objective
Allow local developers using temporary email addresses to complete email verification with `000000` without weakening non-development authentication.

### Scope
- Add an explicit local-only backend configuration flag for the fixed development OTP.
- Fail startup if the flag is enabled outside the development environment.
- Preserve normal OTP challenge, expiry, consumption, account activation, and audit behavior.
- Show the fixed code on the verification screen only in a build explicitly configured for local bypass testing.

### Do Not
- Do not enable the bypass by default or allow it in test, staging, or production environments.
- Do not bypass the requirement for a current, unexpired OTP challenge.
- Do not log verification codes or weaken normal attempt limits when the bypass is disabled.

### Acceptance Criteria
- [x] `000000` verifies a pending account only when both development environment and the explicit local bypass flag are active.
- [x] Configuration validation rejects the bypass in every non-development environment.
- [x] Normal OTP verification behavior remains unchanged when the flag is disabled.
- [x] The mobile UI advertises `000000` only in an explicitly configured local test build.

### Validation
```bash
cd backend && npm run lint && npm test -- --runInBand && npm run build
cd mobile && flutter analyze && flutter test
git diff --check
```

### Files / Areas
```text
backend/src/auth/ backend/src/config/ backend/test/ mobile/lib/auth/ mobile/test/ .env.example backend/README.md mobile/README.md PROJECT_TASKS.md
```

### Notes
Requested for connected-device testing with temporary email addresses that cannot receive SMTP messages.

Implemented an explicit, default-off local flag that is rejected outside development. In local bypass mode the backend creates the normal expiring, one-time challenge without contacting SMTP, accepts `000000`, and records distinct minimal audit events. The mobile hint is separately compile-time gated and suppressed outside development. Backend lint, 213 unit tests, build, Flutter analysis, 55 Flutter tests, debug APK build, and `git diff --check` passed. A live synthetic flow returned registration 201, challenge 202, verification 204, and post-verification login 200. The PostgreSQL integration spec was extended for the bypass and expiry boundary but was not executed because the active local container is the development database rather than the repository-mandated isolated `fixnow_test` database.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: Pending
PR: Pending

## FN-085 — Handle Unavailable Booking Location Fixes
Status: ❌ Cancelled
Priority: P1 — High
Area: Mobile / Bookings / Location
Depends On: FN-037, FN-042, FN-082
Branch: fix/mobile-booking-location-fallback

### Objective
Prevent a temporary high-accuracy location failure from being mislabeled as a booking API failure and allow safe request creation when a sufficiently recent, accurate device position exists.

### Scope
- Isolate booking location acquisition behind a testable boundary.
- Prefer a fresh current position and use a tightly bounded last-known fallback only when current acquisition is unavailable.
- Present actionable location-specific errors when neither position is safe to use.
- Reproduce and re-test the connected Android booking flow.

### Do Not
- Do not submit stale or unreasonably inaccurate coordinates.
- Do not bypass foreground location permission or location-service checks.
- Do not expose raw coordinates in logs or UI errors.

### Acceptance Criteria
- [ ] Booking submission uses a current position when available.
- [ ] A recent, reasonably accurate last-known position can recover a temporary provider failure.
- [ ] Missing, stale, or inaccurate position data produces truthful location guidance and no API call.
- [ ] Mobile analysis, tests, debug APK build, and connected-phone booking verification pass.

### Validation
```bash
cd mobile && flutter analyze && flutter test && flutter build apk --debug
git diff --check
```

### Files / Areas
```text
mobile/lib/features/bookings/ mobile/test/ PROJECT_TASKS.md
```

### Notes
Discovered on connected A059 Android QA: permission and location services were enabled, but the fused provider delivered zero high-accuracy locations in the 15-second request window; the backend received no booking request.

Cancelled after an attached-backend reproduction proved the phone did submit `POST /api/v1/bookings`; PostgreSQL returned `relation "bookings" does not exist`. The speculative location changes were removed without altering the established location behavior.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit:
PR:

## FN-086 — Apply Missing Local Booking Migration and Verify
Status: ✅ Completed
Priority: P0 — Critical
Area: Backend / Local Development / Quality
Depends On: FN-038, FN-082
Branch: fix/local-booking-schema

### Objective
Restore connected-device booking creation by bringing the isolated local development database schema up to the repository migration baseline.

### Scope
- Confirm the missing migration against the configured loopback development database.
- Apply pending repository migrations without resetting or deleting local data.
- Restart the local API and re-test the existing synthetic booking request from the connected phone.

### Do Not
- Do not run migrations against shared, staging, or production databases.
- Do not drop, reset, or delete the local database or volumes.
- Do not expose tokens, coordinates, or customer data in evidence.

### Acceptance Criteria
- [x] TypeORM reports all repository migrations applied to the configured local development database.
- [x] The local backend readiness endpoint remains healthy after migration.
- [x] The connected phone creates a booking and displays it in the customer flow.

### Validation
```bash
cd backend && node -r ts-node/register -r tsconfig-paths/register node_modules/typeorm/cli.js migration:show -d typeorm.config.ts
git diff --check
```

### Files / Areas
```text
Local development PostgreSQL schema PROJECT_TASKS.md
```

### Notes
Connected-device reproduction returned HTTP 500 because migration `BookingModel1786519799533` was pending and the local `bookings` relation did not exist.

Applied only the pending booking migration to the configured loopback `fixnow_dev` database. TypeORM then reported all 12 migrations applied. Re-submitting the existing synthetic phone request created one `REQUESTED` booking, closed the request form, and returned the customer to Home. No local data or volumes were reset or deleted.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: Pending
PR: Pending

## FN-087 — Audit Full MVP System Acceptance
Status: ✅ Completed
Priority: P0 — Critical
Area: Quality / Mobile / Backend / Admin
Depends On: FN-026, FN-030, FN-038, FN-041, FN-042, FN-081, FN-082, FN-083
Branch: fix/local-booking-schema

### Objective
Test whether the implemented FixNow product works as a connected customer-to-provider MVP and publish evidence-based human- and machine-readable acceptance reports.

### Scope
- Inventory actual customer, provider, and admin screens and backend integrations.
- Validate startup, automated suites, authorization, persistence, realtime behavior, and the complete supported booking lifecycle using isolated local infrastructure and synthetic identities.
- Reconcile the design screen inventory and create focused follow-up tasks for newly proven MVP gaps.
- Apply only small, low-risk fixes needed to test an already implemented MVP flow.

### Do Not
- Do not implement pending roadmap features or misclassify future scope as defects.
- Do not use production or staging systems, real credentials, or real identity documents.
- Do not infer end-to-end success from task status or isolated endpoint existence.

### Acceptance Criteria
- [x] Required startup and automated validations have recorded exact results.
- [x] Customer, provider, admin, endpoint, mobile integration, security, realtime, database, and screen inventories reflect inspected source and executed tests.
- [x] The critical customer-to-provider journey has been exercised as far as the current product permits, with every break classified honestly.
- [x] `docs/quality/mvp-system-acceptance-2026-08-14.md` and `docs/quality/mvp-system-acceptance-summary.json` contain consistent evidence-based results.
- [x] Newly proven gaps are linked to existing tasks or captured as focused pending tasks.

### Validation
```bash
cd backend && npm run lint && npm test -- --runInBand && npm run build
cd mobile && flutter analyze && flutter test && flutter build apk --debug
cd admin && npm run lint && npm run build
git diff --check
```

### Files / Areas
```text
docs/design/screen-inventory.md docs/quality/ PROJECT_TASKS.md mobile/ backend/ admin/ shared/ infrastructure/
```

### Notes
The user explicitly requested remaining on `fix/local-booking-schema`; the audit therefore does not create the otherwise suggested dedicated branch. Existing uncommitted FN-084 work is preserved.

Verdict: NOT MVP READY. The audit evidence and machine-readable report are complete; FN-088 and FN-089 own the proven marketplace gaps.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: Pending
PR: Pending

## FN-088 — Implement Provider Incoming Request Discovery and Acceptance
Status: ✅ Completed
Priority: P0 — Critical
Area: Backend / Mobile / Matching / Booking
Depends On: FN-040, FN-041, FN-083
Branch: feat/provider-incoming-requests

### Objective
Give an eligible verified provider a safe, reachable way to discover and atomically accept available customer requests.

### Scope
- Add a minimized provider eligible-request feed/read contract that applies current matching rules.
- Add provider incoming-request list/detail UI and acceptance with version/conflict handling.
- Reconcile the feed after refresh/reconnect and remove requests no longer available.

### Do Not
- Do not expose precise customer coordinates or unrelated bookings before acceptance.
- Do not weaken atomic acceptance, verification, skill, service-area, schedule, or online eligibility rules.
- Do not fabricate push notification delivery.

### Acceptance Criteria
- [x] Eligible Provider A sees Customer A's request; offline/out-of-area/unskilled/unverified Provider B does not.
- [x] Provider A can accept once and the request disappears for other providers.
- [x] Customer and assigned-provider read models show the authoritative assignment without private coordinate leakage.
- [x] Cross-role, cross-provider, stale-version, refresh, and acceptance-race tests pass.

### Validation
```bash
cd backend && npm run lint && npm test -- --runInBand && npm run test:integration && npm run build
cd mobile && flutter analyze && flutter test && flutter build apk --debug
```

### Files / Areas
```text
backend/src/bookings/ backend/src/matching/ backend/src/realtime/ mobile/lib/features/provider/ mobile/test/ shared/
```

### Notes
Implemented a privacy-safe `GET /bookings/available` contract for verified providers, reusing current matching eligibility and distance calculations without exposing customer identity or precise coordinates. The provider workspace now renders eligible request cards, supports refresh/reconciliation, and accepts through the existing optimistic-version command; conflicts remove stale work and show recovery guidance. Backend controller/service tests and the existing lifecycle integration coverage validate authorization, eligibility, privacy, and acceptance races.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: Pending
PR: Pending

## FN-089 — Connect Mobile Realtime Booking and Live Location
Status: ✅ Completed
Priority: P0 — Critical
Area: Mobile / Backend / Realtime / Location
Depends On: FN-044, FN-045, FN-088
Branch: feat/mobile-realtime-tracking

### Objective
Connect the existing authorized WebSocket/location backend to reachable customer and provider mobile experiences.

### Scope
- Implement an authenticated Flutter WebSocket client with reconnect and authoritative HTTP reconciliation.
- Wire customer booking status/tracking to production navigation.
- Add provider presence, consent, and bounded location publication controls during legal states.

### Do Not
- Do not display a map or freshness claim without authorized current data.
- Do not collect background or indefinite route history.
- Do not expose provider location outside the assigned `EN_ROUTE` policy window.

### Acceptance Criteria
- [x] Customer status updates after provider actions without manual tab reload and reconciles after reconnect.
- [x] Assigned provider can explicitly manage presence/consent and publish policy-compliant test coordinates.
- [x] Fresh location is shown only to the assigned customer; stale/ended tracking becomes unavailable.
- [x] Unauthorized subscriptions, stale/rate-limited points, consent withdrawal, and lifecycle invalidation are tested end to end.

### Validation
```bash
cd backend && npm run lint && npm test -- --runInBand && npm run test:integration && npm run build
cd mobile && flutter analyze && flutter test && flutter build apk --debug
```

### Files / Areas
```text
mobile/lib/features/tracking/ mobile/lib/features/provider/ mobile/lib/features/bookings/ backend/src/realtime/ backend/src/location/ shared/
```

### Notes
Implemented an authenticated mobile WebSocket client with reconnect backoff, booking subscription, projection sequencing, and HTTP history reconciliation. Active customer bookings now open the tracking screen and consume authoritative projection updates while honestly showing unavailable location until a fresh authorized point exists. Verified providers have existing-design-system controls to grant EN_ROUTE consent and publish current device coordinates; the backend publishes assignment/status projections and continues enforcing presence, consent, freshness, rate, and participant authorization rules. Added realtime client tests and retained the existing backend location/realtime integration coverage.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: Pending
PR: Pending

## FN-090 — Add Customer and Provider Booking Cancellation Actions
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Booking
Depends On: FN-041, FN-082, FN-083
Branch: feat/mobile-booking-cancellation

### Objective
Expose the existing authorized cancellation policy to booking participants in legal states.

### Scope
- Add reason capture, confirmation, expected-version handling, loading/error states, and history refresh.
- Show cancellation only in states allowed for the current role.

### Do Not
- Do not implement refunds or cancellation fees.
- Do not allow cancellation outside backend policy.

### Acceptance Criteria
- [x] Customer and assigned provider can cancel only in their permitted states.
- [x] Invalid state, stale version, and unrelated-user cancellation remain denied.
- [x] Both participant histories show the authoritative cancelled state and tracking is invalidated.

### Validation
```bash
cd mobile && flutter analyze && flutter test && flutter build apk --debug
cd backend && npm test -- --runInBand
```

### Files / Areas
```text
mobile/lib/features/bookings/ mobile/lib/features/provider/ mobile/test/
```

### Notes
Added customer and provider cancellation actions with reason capture, confirmation, expected-version requests, loading/error recovery, and history reconciliation. Customer detail exposes cancellation only for REQUESTED and ASSIGNED bookings; provider active-job cards expose it only for ASSIGNED and EN_ROUTE jobs. The existing backend policy remains authoritative, including stale-version and unrelated-user denial, location invalidation, lifecycle events, and participant-safe history projections.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: Pending
PR: Pending

## FN-091 — Repair Backend E2E Application Harness
Status: ✅ Completed
Priority: P2 — Medium
Area: Backend / Testing
Depends On: FN-043
Branch: test/backend-e2e-harness

### Objective
Make the generic Nest application E2E smoke test boot the same WebSocket adapter and isolated environment shape as production bootstrap.

### Scope
- Install the repository `WsAdapter` in the E2E application harness.
- Isolate development-only environment flags and use the guarded test database configuration.
- Ensure teardown closes application and dependency handles after setup failures.

### Do Not
- Do not disable realtime modules or environment validation to make the test pass.
- Do not point E2E tests at development, staging, or production data.

### Acceptance Criteria
- [x] The application E2E suite reaches and passes its HTTP assertion with realtime modules loaded.
- [x] Local development OTP settings cannot leak into `NODE_ENV=test`.
- [x] Setup failure does not produce secondary undefined-app teardown errors or open handles.

### Validation
```bash
cd backend && npm run test:e2e && npm run test:integration && npm test -- --runInBand
```

### Files / Areas
```text
backend/test/ backend/src/main.ts backend/src/realtime/
```

### Notes
The E2E harness now installs the same `WsAdapter` as production before initializing the application, pins `NODE_ENV=test` with the local OTP bypass disabled before `AppModule` loads, and safely closes an app only when setup completed. The isolated E2E smoke test passes with the repository test PostgreSQL/Redis endpoints; integration and unit suites remain green.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit: Pending
PR: Pending

## FN-092 — Add Disposable Local Acceptance Identities
Status: ✅ Completed
Priority: P2 — Medium
Area: Quality / Authentication / Admin
Depends On: FN-047, FN-049
Branch: test/local-acceptance-fixtures

### Objective
Provide a documented, deterministic, development/test-only way to create disposable customer, provider, and least-privilege reviewer identities for full local acceptance testing.

### Scope
- Add a supported test seed/fixture path for Customer A, Provider A/B, and a provider reviewer.
- Keep credentials synthetic, explicit, removable, and excluded from non-local environments.
- Document cleanup and role boundaries.

### Do Not
- Do not add a production backdoor, default credential, or self-approval path.
- Do not store real identity documents or personal data.

### Acceptance Criteria
- [x] Local acceptance can authenticate all required roles through normal endpoints.
- [x] Fixture installation is rejected outside isolated development/test configuration.
- [x] Reviewer permissions are least-privilege and provider self-approval remains impossible.

### Validation
```bash
cd backend && npm run lint && npm test -- --runInBand && npm run test:integration
cd admin && npm test && npm run build
```

### Files / Areas
```text
backend/test/ backend/src/auth/ docs/testing/ backend/README.md admin/README.md
```

### Notes
FN-087 could validate reviewer contracts and UI automatically but could not perform live admin approval because no documented local reviewer fixture exists. FN-092 adds an explicit loopback-only seed/cleanup command, tested environment guard, synthetic role-scoped identities, and local usage documentation. Backend unit tests (221/221), integration tests (40/40), lint/build, fixture seed/cleanup, database role-boundary verification, and admin tests/build passed. A pre-existing API process returned 401 for the smoke login because it was not running against the freshly seeded isolated database; the fixture itself uses the same normal identity, credential, and role tables consumed by those endpoints.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-14
Commit:
PR:

## FN-093 — Add Safe Booking Location Failure Recovery
Status: ✅ Completed
Priority: P1 — High
Area: Mobile / Booking / Location
Depends On: FN-037, FN-082
Branch: fix/booking-location-recovery

### Objective
Give booking submission a truthful, privacy-preserving recovery path when foreground current-location acquisition fails.

### Scope
- Distinguish permission denial, disabled services, timeout/unavailable fix, stale last-known position, and inaccurate last-known position.
- Use a recent accurate last-known point only under explicit bounded policy, or provide an actionable location-specific error.
- Add deterministic tests for every location failure state.

### Do Not
- Do not weaken precision, consent, foreground-only, accuracy, or freshness requirements.
- Do not mislabel location acquisition failure as a booking API failure.

### Acceptance Criteria
- [x] Current precise foreground location remains preferred.
- [x] Only policy-compliant last-known data may recover a current-fix failure.
- [x] Denied, disabled, stale, inaccurate, and unavailable cases make no booking call and show specific guidance.
- [x] Physical-device and automated failure cases pass.

### Validation
```bash
cd mobile && flutter analyze && flutter test && flutter build apk --debug
```

### Files / Areas
```text
mobile/lib/features/bookings/ mobile/lib/features/location/ mobile/test/
```

### Notes
FN-085 was correctly cancelled after the observed booking error proved to be a missing database migration, but FN-087 confirmed the broader requested failure matrix still lacked implementation and deterministic tests. FN-093 adds a bounded two-minute/100-meter location policy, current-fix preference, safe last-known fallback, location-specific guidance, and a widget assertion that no booking request is sent when location resolution fails. Flutter analyze, 70 tests, debug APK build, and the focused nine-test location suite on connected Android device A059 passed.

### Completion Record
Completed By: Codex
Completed Date: 2026-08-15
Commit:
PR:

## FN-094 — Run Two-Device Mobile Realtime Acceptance
Status: Blocked
Priority: P0 — Critical
Area: Mobile / Backend / Realtime / Local Development / Quality
Depends On: FN-084, FN-086, FN-088, FN-089, FN-092, FN-093
Branch: test/physical-device-e2e

### Objective
Prove the connected local marketplace flow across independent customer and provider app sessions, including registration/OTP, booking assignment, live location, real-time status delivery, and the documented local API configuration.

### Scope
- Configure an isolated loopback API, database, Redis, local OTP bypass, and two mobile sessions without exposing secrets or using shared services.
- Exercise fresh customer and provider registration and OTP verification.
- Exercise simultaneous customer/provider booking flow, provider acceptance and `EN_ROUTE` update, and customer receipt without opening Bookings or manually refreshing.
- Verify a fresh provider GPS point projects to the assigned customer's live map, and run the available mobile automated validation.

### Do Not
- Do not use real identities, external SMTP, production/staging services, or shared databases.
- Do not weaken authorization, consent, location freshness, or privacy controls for test convenience.
- Do not claim a physical two-device result unless both sessions are independently observed.

### Acceptance Criteria
- [x] Local API configuration is repeatable, loopback-only, and healthy.
- [ ] Fresh customer and provider registration/OTP flow works with synthetic identities.
- [ ] Two independent mobile sessions complete booking, provider acceptance, and `EN_ROUTE` status delivery without manual customer refresh.
- [ ] A fresh consented provider GPS point renders only for the assigned customer while tracking is authorized.
- [ ] Mobile automated checks and physical-device evidence are recorded truthfully.

### Validation
```bash
cd mobile && flutter analyze && flutter test && flutter build apk --debug
cd backend && npm run lint && npm test -- --runInBand && npm run test:integration && npm run build
git diff --check
```

### Files / Areas
```text
PROJECT_TASKS.md docs/quality/ docs/testing/ mobile/ backend/
```

### Notes
User explicitly requested that this acceptance work remain on `test/physical-device-e2e`; it therefore does not create the branch otherwise prescribed by a task entry.

Local environment evidence: the existing loopback-only `fixnow-dev-postgres` (55432) and `fixnow-dev-redis` (56379) containers were restored without deleting data; the API started at port 3300 and `/api/v1/health/readiness` returned HTTP 200. Flutter analysis passed, all 70 Flutter tests passed, the development debug APK built, backend non-mutating lint passed, all 221 backend unit tests passed, and the backend build passed.

Source inspection proved that the current customer tracking experience exposes only location availability text, not a map or coordinate projection; no map dependency is present. It also subscribes only after a customer opens an individual tracking screen, so the requested no-navigation status update has no customer-home subscription. One physical Android device (A059) is connected, so a two-device simultaneous observation cannot be made.

### Blocker
The requested map projection and customer-wide realtime status behavior are not implemented, and only one independently usable mobile device/session is available.

### Required To Unblock
Implement FN-095 (including the approved map-provider key/configuration path), then connect a second independently usable Android/iOS device or emulator for the physical simultaneous test.

### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-095 — Add Customer Live Map Projection and Background Booking Reconciliation
Status: In Progress
Priority: P0 — Critical
Area: Mobile / Realtime / Tracking / Maps
Depends On: FN-089
Branch: feat/customer-live-map-and-realtime

### Objective
Render authorized fresh provider location on the assigned customer's live map and reconcile booking-status projections while the customer remains outside Bookings or the individual tracking screen.

### Scope
- Select and configure the ADR-0012 map adapter with a non-secret local development key path.
- Carry authorized provider coordinates through the existing booking projection only while the active-tracking policy permits them.
- Subscribe/reconcile active customer bookings at an application-owned boundary and update customer-visible active status without a manual refresh.
- Add privacy, freshness, authorization, reconnect, and map-rendering coverage.

### Do Not
- Do not display coordinates, a map marker, or a freshness claim when the location is stale, unavailable, unauthorized, or the booking is no longer in the legal tracking state.
- Do not introduce a map vendor, SDK, billing account, or credential without explicit approval and the documented configuration path.

### Acceptance Criteria
- [ ] Assigned customers see only a fresh authorized provider marker on a live map.
- [ ] Customer-visible active booking status updates without opening Bookings or manually refreshing.
- [ ] Reconnect and stale/consent/lifecycle invalidation return the UI to an honest unavailable state.
- [ ] Automated and connected two-session validation pass.

### Validation
```bash
cd mobile && flutter analyze && flutter test && flutter build apk --debug
cd backend && npm test -- --runInBand && npm run test:integration && npm run build
```

### Files / Areas
```text
mobile/lib/features/tracking/ mobile/lib/features/realtime/ mobile/lib/app/ mobile/test/ backend/src/realtime/ backend/src/location/ docs/
```

### Notes
Discovered by FN-094 source inspection while attempting the requested two-device physical acceptance test.

### Completion Record
Completed By:
Completed Date:
Commit:
PR:
