# FixNow architecture

This document describes the intended system boundaries. It is a direction for future implementation, not evidence that any application already exists.

## Goals

- Keep product surfaces independently buildable and deployable.
- Share stable contracts without coupling application internals.
- Make security, observability, and configuration explicit at system boundaries.
- Allow the implementation stack to evolve through documented decisions.

## Planned context map

```text
                         +-------------------+
                         |      shared/      |
                         | contracts/schemas |
                         +---------+---------+
                                   ^
                 consumes contracts|consumes contracts
                                   |
+-----------+    HTTPS/events    +--+--------+    HTTPS/events    +-----------+
| mobile/   | <----------------> | backend/  | <----------------> | admin/    |
| client    |                    | services  |                    | web app   |
+-----------+                    +-----+------+                    +-----------+
                                      |
                         governed APIs/events
                                      |
                                +-----v-----+
                                |    ai/    |
                                | AI domain |
                                +-----------+

              infrastructure/ provisions and operates all deployable units
```

The arrows describe intended contract-level communication. They do not authorize direct imports between application source trees.

## Component responsibilities

### Mobile

`mobile/` will own the end-user mobile experience, local presentation state, device integration, and calls to documented backend contracts. It must not contain server business rules or server credentials.

### Backend

`backend/` will own APIs, authentication and authorization enforcement, domain workflows, persistence access, background jobs, and integrations. Domain logic should remain separate from controllers, transports, and vendor adapters.

### Admin

`admin/` will own internal administrative workflows. The backend remains the authorization authority; hiding a control in the UI is not access control.

### Shared

`shared/` will own deliberately shared schemas, API or event contracts, generated clients, and cross-project tooling. Application-specific utilities stay with their application. Breaking contract changes require versioning and migration notes.

### Infrastructure

`infrastructure/` will own infrastructure as code, deployment definitions, environment configuration schemas, monitoring, and operational runbooks. Secrets belong in an approved secret manager, never in this directory.

### AI

`ai/` will own model integrations, prompts, evaluation datasets without sensitive data, guardrails, and AI-specific services. Model output must be treated as untrusted input and validated before it causes side effects.

## Dependency rules

1. Applications may depend on published artifacts from `shared/`.
2. Applications may not import another application's internal modules.
3. Client applications communicate with backend capabilities through authenticated, versioned contracts.
4. Backend and AI integration occurs through explicit interfaces with timeouts, failure handling, auditability, and cost controls.
5. Infrastructure may reference build outputs and deployment metadata but must not become the owner of application business logic.

## Cross-cutting concerns

- **Identity and access:** central policy enforcement in trusted backend boundaries; least privilege for users and services.
- **Data:** classify data before storage, minimize collection, encrypt in transit and at rest, and define retention and deletion behavior.
- **Observability:** structured logs, metrics, and traces with correlation identifiers; never record secrets or sensitive payloads.
- **Reliability:** bounded retries, idempotency for retried operations, timeouts for network calls, health checks, and documented rollback.
- **Configuration:** environment-based, validated at startup, with safe defaults for local development and no embedded credentials.
- **Contracts:** schema validation at boundaries and compatibility checks in CI once applications exist.

## Environments

The expected progression is local, development, staging, and production. Exact cloud providers, regions, databases, queues, and deployment topology are intentionally undecided. Select them through ADRs after requirements are known.

## Decisions intentionally deferred

- Cloud and deployment platform
- Database and cache products
- Authentication provider and identity model
- API style and event transport
- Monorepo package manager and build orchestrator
- AI model providers and data governance controls

Deferring these prevents a foundation commit from silently locking the project into vendors before product and operational requirements exist.

## Architecture decision records

Create a numbered ADR in [`decisions/`](decisions/) for material choices. Copy [`0000-template.md`](decisions/0000-template.md), assign the next number, and keep superseded records for historical context.
