# ADR-0001: Adopt a versioned JSON HTTP API

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering

## Context

FixNow plans independently buildable mobile and admin clients, a backend authority for domain workflows, and later model-facing or external integrations. These boundaries require a synchronous contract that is widely supported, observable, cache-aware, toolable, and independent of any application framework.

The architecture overview already places HTTPS at application boundaries but intentionally deferred the API style. FN-011 requires versioning, naming, pagination, idempotency, validation, errors, retry behavior, compatibility, and correlation conventions before backend or client scaffolding begins.

The initial API consumers need conventional request/response interactions. Real-time delivery and asynchronous domain events have different ordering, delivery, and compatibility concerns and are handled separately by FN-015.

## Decision

FixNow synchronous application APIs will use resource-oriented HTTP over HTTPS with UTF-8 JSON representations.

- Application endpoints use path-based major versions such as `/api/v1/...`.
- Resources use standard HTTP method semantics and status codes.
- Errors use `application/problem+json` Problem Details semantics with stable FixNow codes and correlation IDs.
- Growing collections use opaque cursor pagination by default.
- Non-repeatable retryable operations use an explicit idempotency-key protocol.
- Contracts follow the compatibility, validation, security, concurrency, retry, and documentation rules in [`../api-conventions.md`](../api-conventions.md) and [`../error-response-conventions.md`](../error-response-conventions.md).
- The decision does not select a backend framework, schema tool, authentication provider, event transport, WebSocket protocol, database, cache, or hosted vendor.

## Consequences

### Positive

- Mobile, web, administrative, and service clients can use ubiquitous HTTP and JSON tooling.
- Method and status semantics support gateways, diagnostics, conditional requests, caching controls, and standard operational practices.
- Path major versions give operators and clients an explicit compatibility boundary.
- Problem Details provides a standard base while stable application codes support deterministic client behavior.
- Framework independence lets later tasks select implementation tooling without changing the public contract style.

### Costs and risks

- Teams must actively govern schemas; JSON alone does not enforce runtime correctness or compatibility.
- Resource-oriented HTTP can represent complex workflows poorly if lifecycle commands are forced into generic updates; explicit command endpoints are therefore allowed.
- Supporting overlapping major versions creates test, operations, and migration cost.
- Cursor and idempotency implementations require state, integrity protection, retention policy, and focused tests.
- JSON is less compact than binary protocols for high-frequency streams, so this decision does not govern live location or event transport.

### Follow-up

- FN-015 will define real-time and notification/event architecture.
- Backend foundation work will select a machine-readable schema source and compatibility checks without changing these external semantics.
- Each public contract must receive security, privacy, authorization, retry, and compatibility review proportional to risk.

## Alternatives considered

### GraphQL as the primary application API

GraphQL offers flexible client selection and a strong schema ecosystem. It was not selected as the primary style because authorization, caching, query-cost control, idempotent commands, operational status semantics, and error governance would require additional project-specific conventions before the foundation exists. A future bounded use would require a superseding or scoped ADR.

### gRPC as the primary application API

gRPC offers typed contracts and efficient service communication. It was not selected for the primary mobile/admin boundary because browser and intermediary support, public diagnostics, and client deployment compatibility add complexity. A future internal use would require its own ADR and must not leak application-private contracts across repository boundaries.

### Unversioned HTTP endpoints

Unversioned endpoints reduce visible path complexity but make breaking migrations and overlapping client releases harder to operate. Mobile clients cannot be upgraded atomically, so an explicit major compatibility boundary is preferred.

### Transport-neutral documentation only

Purely transport-neutral rules would avoid a decision now but would leave status, media type, caching, conditional requests, retry, and error semantics ambiguous for backend and client foundation tasks.

## Validation

- Review every initial endpoint against the API contract checklist.
- Add machine-readable schema validation and breaking-change detection when the backend contract toolchain is chosen.
- Test status codes, media types, error codes, correlation IDs, validation, authorization, pagination, concurrency, idempotency, and retry semantics at API boundaries.
- Reconsider this decision if measured client, streaming, partner, performance, or operability requirements cannot be met without systematically fighting HTTP semantics.
