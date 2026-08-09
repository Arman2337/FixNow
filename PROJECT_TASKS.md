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

Total Tasks: 72
Completed: 16
In Progress: 0
Blocked: 0
Pending: 56
Cancelled: 0
Current Phase: Phase 1 — Project Architecture
Next Recommended Task: FN-017 — Initialize Backend Application

# Current Work

Active Tasks:

- None

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
Commit: Pending
PR: Pending

# Phase 2 — Backend Foundation

## FN-017 — Initialize Backend Application
Status: ⬜ Pending
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
Completed By:
Completed Date:
Commit:
PR:

## FN-018 — Add Backend Configuration and Structured Logging
Status: ⬜ Pending
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
Completed By:
Completed Date:
Commit:
PR:

## FN-019 — Add PostgreSQL Persistence Foundation
Status: ⬜ Pending
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
Completed By:
Completed Date:
Commit:
PR:

## FN-020 — Add Redis Cache and Coordination Foundation
Status: ⬜ Pending
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
Completed By:
Completed Date:
Commit:
PR:

## FN-021 — Add Backend Request Validation and Global Error Handling
Status: ⬜ Pending
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
Completed By:
Completed Date:
Commit:
PR:

## FN-022 — Add Backend Health and Readiness Endpoints
Status: ⬜ Pending
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
Completed By:
Completed Date:
Commit:
PR:

# Phase 3 — Authentication & Users

## FN-023 — Create User and Identity Data Model
Status: ⬜ Pending
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
- [ ] Constraints, lifecycle states, migration rollback, and repository tests pass.
### Validation
```bash
# Run backend checks plus identity migration and repository tests.
```
### Files / Areas
```text
backend/src/users/ backend/migrations/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-024 — Implement Customer Registration and Login
Status: ⬜ Pending
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
- [ ] Success, duplicate, invalid, enumeration, and throttling boundaries are tested.
### Validation
```bash
# Run backend checks and customer authentication integration tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/users/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-025 — Implement Provider Registration
Status: ⬜ Pending
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
- [ ] Registration, duplicate, invalid-state, and permission tests pass.
### Validation
```bash
# Run backend checks and provider registration integration tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/providers/ backend/src/users/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-026 — Implement OTP and Refresh-Token Lifecycles
Status: ⬜ Pending
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
- [ ] Expiry, replay, brute-force, rotation, and revocation tests pass.
### Validation
```bash
# Run backend checks and focused OTP/token security tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/notifications/
```
### Notes
External delivery credentials may require blocking this task.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-027 — Enforce Role-Based Authorization
Status: ⬜ Pending
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
- [ ] Cross-role, inactive-account, ownership, and privilege-escalation tests pass.
### Validation
```bash
# Run backend checks and authorization matrix tests.
```
### Files / Areas
```text
backend/src/auth/ backend/src/common/ docs/security/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-028 — Implement Customer Profile Management
Status: ⬜ Pending
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
- [ ] Read, update, validation, ownership, and privacy tests pass.
### Validation
```bash
# Run backend checks and customer profile integration tests.
```
### Files / Areas
```text
backend/src/users/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 4 — Provider System

## FN-029 — Model Service Categories and Provider Skills
Status: ⬜ Pending
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
Completed By:
Completed Date:
Commit:
PR:

## FN-030 — Implement Provider Profile and Service Areas
Status: ⬜ Pending
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
- [ ] Profile, skill, radius, ownership, and geospatial boundary tests pass.
### Validation
```bash
# Run backend checks and provider profile integration tests.
```
### Files / Areas
```text
backend/src/providers/ backend/src/services/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-031 — Implement Provider Document Upload
Status: ⬜ Pending
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
- [ ] Upload, rejection, access, deletion, and audit tests pass.
### Validation
```bash
# Run backend checks and isolated document integration tests.
```
### Files / Areas
```text
backend/src/providers/documents/ backend/src/storage/ infrastructure/
```
### Notes
Storage provider and credentials must be available or the task is blocked.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-032 — Implement Provider Verification Workflow
Status: ⬜ Pending
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
- [ ] Transition, permission, concurrency, reason, and audit tests pass.
### Validation
```bash
# Run backend checks and verification workflow tests.
```
### Files / Areas
```text
backend/src/providers/ backend/src/admin/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-033 — Implement Provider Availability
Status: ⬜ Pending
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
- [ ] Time-zone, overlap, authorization, and verified-state tests pass.
### Validation
```bash
# Run backend checks and provider availability tests.
```
### Files / Areas
```text
backend/src/providers/availability/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 5 — Customer Mobile Foundation

## FN-034 — Initialize Flutter Mobile Application
Status: ⬜ Pending
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
- [ ] App runs, `flutter analyze` passes, and default tests pass.
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
Flutter must be explicitly approved and recorded before initialization.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-035 — Establish Mobile Navigation, State, and Design System
Status: ⬜ Pending
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
- [ ] Navigation, theme, accessibility, and component tests pass.
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
State-management choice must be documented.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-036 — Add Mobile API Client and Authentication State
Status: ⬜ Pending
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
- [ ] Authenticated, expired, offline, retry, and logout cases pass.
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
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-037 — Implement Customer Profile, Location, and Service Discovery UI
Status: ⬜ Pending
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
- [ ] Permission denial, privacy, loading, error, and accessibility tests pass.
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
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 6 — Service Booking

## FN-038 — Create Booking Data Model and Lifecycle Contract
Status: ⬜ Pending
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
- [ ] Constraints, legal transitions, rollback, and concurrency tests pass.
### Validation
```bash
# Run backend checks plus booking model and migration tests.
```
### Files / Areas
```text
backend/src/bookings/domain/ backend/migrations/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-039 — Implement Service Request Creation
Status: ⬜ Pending
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
- [ ] Validation, duplicate, authorization, privacy, and idempotency tests pass.
### Validation
```bash
# Run backend checks and service-request integration tests.
```
### Files / Areas
```text
backend/src/bookings/ backend/src/location/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-040 — Implement Provider Matching
Status: ⬜ Pending
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
- [ ] Eligibility, no-match, ordering, privacy, and load boundaries are tested.
### Validation
```bash
# Run backend checks and provider matching tests.
```
### Files / Areas
```text
backend/src/matching/ backend/src/providers/ backend/src/bookings/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-041 — Implement Provider Acceptance and Booking Progress
Status: ⬜ Pending
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
- [ ] Race, stale update, role, ownership, and lifecycle tests pass.
### Validation
```bash
# Run backend checks and booking lifecycle integration tests.
```
### Files / Areas
```text
backend/src/bookings/ backend/src/matching/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-042 — Implement Booking Cancellation and Service History
Status: ⬜ Pending
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
- [ ] Policy, race, authorization, pagination, and data-minimization tests pass.
### Validation
```bash
# Run backend checks and cancellation/history tests.
```
### Files / Areas
```text
backend/src/bookings/ shared/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 7 — Real-Time & Location

## FN-043 — Add Authenticated WebSocket Infrastructure
Status: ⬜ Pending
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
- [ ] Authentication, authorization, reconnect, limit, and failure tests pass.
### Validation
```bash
# Run backend checks and WebSocket integration tests.
```
### Files / Areas
```text
backend/src/realtime/ infrastructure/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-044 — Implement Provider Presence and Live Location Ingestion
Status: ⬜ Pending
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
- [ ] Consent, stale, rate, authorization, retention, and offline tests pass.
### Validation
```bash
# Run backend checks and live-location integration tests.
```
### Files / Areas
```text
backend/src/location/ backend/src/realtime/ backend/src/providers/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-045 — Implement Booking Tracking, ETA, and Real-Time Events
Status: ⬜ Pending
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
- [ ] Authorization, ordering, reconnect, stale location, fallback, and UI tests pass.
### Validation
```bash
# Run backend real-time tests and mobile analyze/test commands.
```
### Files / Areas
```text
backend/src/bookings/ backend/src/realtime/ mobile/lib/features/tracking/ shared/
```
### Notes
Coordinate backend and mobile contract edits within this single task.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

# Phase 8 — Admin Dashboard

## FN-046 — Initialize Admin Web Application
Status: ⬜ Pending
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
- [ ] App starts and lint, type, build, and default tests pass.
### Validation
```bash
# Run the admin package-manager lint, type-check, test, and build commands.
```
### Files / Areas
```text
admin/
```
### Notes
Next.js is a candidate requiring explicit approval and rationale.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-047 — Implement Admin Authentication and Authorization UI
Status: ⬜ Pending
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
- [ ] Login, expiry, unauthorized, logout, and accessibility tests pass.
### Validation
```bash
# Run admin lint, type-check, tests, and build.
```
### Files / Areas
```text
admin/src/auth/ admin/src/app/ backend/src/auth/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-048 — Implement Admin User and Provider Verification Management
Status: ⬜ Pending
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
- [ ] Permission, redaction, review, concurrency, and accessibility tests pass.
### Validation
```bash
# Run admin checks and relevant backend integration tests.
```
### Files / Areas
```text
admin/src/features/users/ admin/src/features/providers/ backend/src/admin/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

## FN-049 — Implement Admin Service and Booking Management
Status: ⬜ Pending
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
- [ ] Authorization, validation, search, audit, and accessibility tests pass.
### Validation
```bash
# Run admin checks and relevant backend integration tests.
```
### Files / Areas
```text
admin/src/features/services/ admin/src/features/bookings/ backend/src/admin/
```
### Notes
None.
### Completion Record
Completed By:
Completed Date:
Commit:
PR:

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
