# API conventions

## Status and scope

These conventions are normative for FixNow's synchronous application APIs. They apply to mobile, admin, partner-facing, and service-to-service request/response contracts unless a reviewed specification explicitly states a stricter rule. They do not define asynchronous event transport or payload conventions; those remain part of FN-015.

The transport decision and rationale are recorded in [ADR-0001](decisions/0001-adopt-versioned-json-http-api.md). Implementation examples are illustrative contracts, not evidence that endpoints exist.

Normative terms such as **MUST**, **MUST NOT**, **SHOULD**, and **MAY** indicate requirement strength.

## Design principles

1. Contracts are public boundaries, even when the current consumer is another FixNow application.
2. The server is authoritative for identity, authorization, domain state, money, and consequential integration outcomes.
3. Requests are validated completely before domain effects occur.
4. Retries are safe only when the operation is naturally idempotent or uses the idempotency protocol.
5. Responses disclose the minimum data the caller is authorized to receive.
6. Compatibility is deliberate: additive evolution is preferred; breaking changes require a new major API version and migration plan.
7. Operational metadata supports diagnosis without exposing internals or sensitive data.

## Protocol and representation

- Production and shared-environment APIs MUST use HTTPS. Plain HTTP MAY be used only for isolated local development.
- Request and response bodies MUST use UTF-8 JSON unless a documented endpoint requires another media type, such as a private file upload.
- JSON requests MUST send `Content-Type: application/json`.
- Successful JSON responses MUST send `Content-Type: application/json`.
- Error responses MUST use `Content-Type: application/problem+json` and the format in [Error response conventions](error-response-conventions.md).
- Clients SHOULD send `Accept: application/json` and MUST tolerate compatible media-type parameters.
- Unsupported request media types return `415 Unsupported Media Type`; unacceptable response types return `406 Not Acceptable` where content negotiation is supported.
- Every endpoint MUST define and enforce a request-size limit. Upload endpoints MUST additionally define allowed types, file count, per-file size, and content-validation behavior.
- API documentation and schemas MUST NOT include real credentials, production identifiers, customer data, KYC documents, or reusable authentication material.

## Base paths and versioning

Application endpoints use this shape:

```text
/api/v{major}/{resource}
```

Example:

```text
/api/v1/service-requests
```

- The major version MUST be an integer in the path.
- All routes below one major prefix share the compatibility policy in this document.
- Minor or patch versions MUST NOT appear in URLs. Compatible changes ship within the existing major version.
- Infrastructure-only endpoints that are not application contracts, such as `/health/live` and `/health/ready`, MAY live outside `/api/v{major}` and MUST remain narrowly scoped.
- The selected major version MUST NOT vary silently by user, role, device, experiment, or deployment environment.
- A breaking change requires a new major path, a migration guide, an overlap period approved by product and operations, and explicit retirement criteria.

## Resource and field naming

### Paths

- Resource collections MUST use plural, lowercase, kebab-case nouns: `/service-requests`, `/provider-documents`.
- A single resource MUST be addressed by an opaque identifier: `/bookings/{bookingId}`.
- Nested paths SHOULD express true ownership or containment and remain shallow: `/bookings/{bookingId}/events`.
- Actions that cannot be represented as resource state MAY use a subordinate verb in kebab-case: `/bookings/{bookingId}/cancel`.
- Paths MUST NOT expose implementation names such as table, ORM, controller, framework module, or vendor SDK names.
- Query parameter names MUST use lower camel case.

### JSON

- Object property names MUST use lower camel case.
- Enum wire values MUST use lowercase kebab-case and be documented as closed or open sets.
- Identifiers MUST be serialized as opaque strings. Clients MUST NOT derive meaning, ordering, tenancy, or resource type from an ID.
- Timestamps MUST be RFC 3339 strings with an explicit offset and SHOULD be normalized to UTC, for example `2026-08-09T12:30:00Z`.
- Calendar dates without a time MUST use `YYYY-MM-DD`.
- Durations MUST state their unit in the field name or use a documented ISO 8601 duration string.
- Monetary values MUST use integer minor units plus an ISO 4217 currency code unless a payment contract documents a stricter representation.
- Geographic coordinates MUST state coordinate order, precision, reference system, and privacy limits in their schema.
- Booleans MUST use JSON `true` and `false`, not `0`, `1`, or string equivalents.
- Binary values MUST NOT be embedded as base64 in ordinary JSON contracts unless a reviewed endpoint specification justifies the size and security impact.

Example money representation:

```json
{
  "amountMinor": 12500,
  "currency": "INR"
}
```

### Missing, null, and empty values

- A missing property means “not supplied” unless the schema says otherwise.
- JSON `null` means “explicitly no value” only for fields whose schema allows null.
- An empty string, empty collection, zero, `false`, a missing property, and `null` MUST NOT be treated as interchangeable.
- Update contracts MUST document whether each field is replaceable, clearable, or immutable.
- Responses SHOULD omit data the caller is not authorized to see; they MUST NOT use a misleading null value to imply an authorized but empty field.

## HTTP method semantics

| Method | Intended use | Idempotent by semantics | Request body |
| --- | --- | --- | --- |
| `GET` | Read a resource or collection | Yes | No |
| `POST` | Create a resource or invoke a documented command | No; use an idempotency key where retry is expected | Usually |
| `PUT` | Replace a resource at a known URI | Yes | Yes |
| `PATCH` | Apply a documented partial update | Not assumed; contract MUST define retry behavior | Yes |
| `DELETE` | Request deletion or removal | Yes at the HTTP effect level | Usually no |

- `GET` and `HEAD` MUST NOT cause user-visible domain side effects.
- A successful `DELETE` retry MUST not recreate or duplicate effects, but authorization and retention policy still apply.
- Domain lifecycle transitions SHOULD use explicit command endpoints when generic field updates would bypass transition rules.
- Bulk operations MUST define item limits, atomicity, partial-failure behavior, and idempotency.

## Success responses

### Status codes

| Status | Use |
| --- | --- |
| `200 OK` | Successful read, update, command, or synchronous result |
| `201 Created` | Resource created; include a `Location` header when the resource has a stable URI |
| `202 Accepted` | Work accepted but not complete; return a status resource or documented polling mechanism |
| `204 No Content` | Success with no response representation |

- APIs MUST NOT return `200` with an error object for a failed operation.
- A `204` response MUST NOT contain a body.
- Success bodies SHOULD represent the resource or operation result directly. A universal `{ "data": ... }` envelope is not used.
- A response MUST include only fields defined by its schema and authorized for the caller.

Example create response:

```http
HTTP/1.1 201 Created
Content-Type: application/json
Location: /api/v1/service-requests/sr_opaque
X-Correlation-ID: 2d41c4d8-46aa-4dd4-9e89-9bd0a06cb83e
```

```json
{
  "id": "sr_opaque",
  "status": "searching",
  "createdAt": "2026-08-09T12:30:00Z"
}
```

## Collection queries

### Cursor pagination

Collections that can grow beyond a small bounded set MUST use cursor pagination.

Request:

```http
GET /api/v1/bookings?limit=25&after=opaque-cursor
```

Response:

```json
{
  "items": [],
  "page": {
    "limit": 25,
    "nextCursor": null,
    "hasMore": false
  }
}
```

- `limit` MUST have documented default and maximum values.
- Cursors MUST be opaque, scoped to the query and caller, integrity-protected where tampering creates risk, and excluded from logs when they contain or reveal sensitive state.
- Clients MUST NOT parse or modify a cursor.
- `nextCursor` MUST be present and nullable; `hasMore` MUST agree with it.
- A malformed, expired, mismatched, or unsupported cursor returns a stable validation problem.
- Offset pagination MAY be used only for small, stable, explicitly bounded administrative datasets where its consistency and performance tradeoffs are documented.
- Total counts are optional because they can be expensive or privacy-sensitive. If supplied, the contract MUST state whether the count is exact or estimated.

### Filtering and sorting

- Filters MUST be allowlisted and typed by the endpoint schema.
- Repeating a multi-value filter or using a delimited representation MUST be consistent within that API version and documented per field.
- `sort` values use a documented field name; a leading `-` means descending, for example `sort=-createdAt`.
- Every sort MUST include a deterministic tie-breaker on an immutable field.
- Unsupported filters or sort fields return a validation problem rather than being silently ignored.
- Search inputs MUST have length limits and MUST NOT be passed directly into database, log, shell, or query-language contexts.

## Request validation

- Every path, query, header, and body input MUST be validated against an explicit schema at the API boundary.
- Validation MUST cover required presence, type, format, length, range, collection size, enum membership, cross-field rules, and relevant business preconditions.
- Malformed JSON returns `400 Bad Request`.
- Syntactically valid input that violates the request schema returns `422 Unprocessable Content`.
- Unknown body properties SHOULD be rejected for command and write requests to detect client mistakes. An endpoint that ignores unknown properties MUST document why compatibility requires it.
- Query parameters not defined by the endpoint MUST be rejected rather than silently changing behavior.
- Validation errors MUST identify safe field paths and machine-readable reasons without echoing secrets or full rejected payloads.
- Validation does not replace authorization or domain invariant checks.
- Normalization, such as trimming or case folding, MUST be explicit and occur before uniqueness or signature-sensitive operations only when the contract permits it.

## Authentication and authorization

- Protected endpoints MUST authenticate the caller and authorize the action and resource independently.
- Missing or invalid authentication returns `401 Unauthorized` with the approved authentication challenge where applicable.
- An authenticated caller lacking permission returns `403 Forbidden` unless resource-existence protection requires `404 Not Found`.
- APIs MUST NOT rely on mobile or admin UI visibility as access control.
- Authentication tokens, session identifiers, OTPs, private document URLs, and payment signatures MUST NOT appear in URLs, problem details, analytics, or logs.
- Resource ownership, role, account state, booking state, and other contextual policy MUST be evaluated at the trusted backend boundary.

## Correlation and tracing

- Every request MUST have a correlation ID and every response, including errors, MUST return it in `X-Correlation-ID`.
- A trusted upstream MAY supply `X-Correlation-ID`. Public client values MUST be treated as untrusted: validate the allowed format and length or replace them.
- The generated canonical form SHOULD be a UUID or another opaque, non-semantic identifier with equivalent collision resistance.
- The same correlation ID SHOULD connect gateway, application, integration, audit-reference, and background-work telemetry for one logical request where safe.
- Correlation IDs MUST NOT contain user IDs, phone numbers, booking IDs, tokens, locations, or other business/sensitive data.
- A correlation ID is diagnostic metadata, not proof of identity, authorization, causation, or idempotency.
- Distributed tracing SHOULD use W3C Trace Context separately. Public trace headers remain untrusted and MUST follow the observability security policy.

## Idempotency

Operations that create financial, booking, notification, or other non-repeatable effects and may be retried MUST support:

```http
Idempotency-Key: client-generated-opaque-value
```

- The key MUST be unique per caller and intended operation and MUST contain no personal or business data.
- The server MUST scope the key by authenticated principal, endpoint/operation, and API major version.
- The server MUST persist an integrity-protected request fingerprint and the terminal response needed for safe replay.
- Reuse with the same effective request returns the original completed result, including its original application status, without repeating domain effects.
- Reuse with a different effective request returns `409 Conflict` with code `idempotency-key-reused`.
- A concurrent duplicate MUST wait for, return, or safely report the in-progress operation according to the endpoint contract; it MUST NOT execute the effect twice.
- Each endpoint MUST document key format limits and retention duration. Until product and operational targets are approved, retention is `TBD` and the endpoint cannot claim retry safety beyond its configured window.
- Idempotency records MUST follow data-minimization and retention requirements and MUST NOT store raw secrets.

## Optimistic concurrency

- Resources vulnerable to lost updates SHOULD expose an `ETag` or explicit version value.
- A protected update SHOULD require `If-Match` with the version last read by the client.
- A missing required precondition returns `428 Precondition Required`.
- A stale precondition returns `412 Precondition Failed` and MUST NOT apply the update.
- Domain commands that race, such as provider acceptance, MUST also enforce atomic domain invariants; HTTP preconditions alone are insufficient.

## Retries, timeouts, and rate limits

### Client retry policy

Clients MAY automatically retry only when all of these are true:

1. The failure is documented as transient.
2. The operation is safe/idempotent or has a valid idempotency key.
3. The client uses bounded attempts, exponential backoff, and jitter.
4. The retry remains useful within the user's operation deadline.

| Outcome | Default retry guidance |
| --- | --- |
| Connection failure before response | Retry safe/idempotent operations; uncertain non-idempotent outcomes require reconciliation |
| `408 Request Timeout` | Retry only safe/idempotent operations |
| `409 Conflict` | Do not blindly retry; reconcile or follow the specific problem code |
| `425 Too Early` | Retry later only if the request can be safely replayed |
| `429 Too Many Requests` | Respect `Retry-After`; apply bounded backoff |
| `500 Internal Server Error` | Retry only when documented and safe; otherwise show a recoverable failure |
| `502 Bad Gateway`, `503 Service Unavailable`, `504 Gateway Timeout` | Retry safe/idempotent operations with bounded backoff and `Retry-After` when present |

- APIs MUST use `Retry-After` for `429` and SHOULD use it for temporary `503` responses when a useful delay is known.
- A client MUST NOT retry validation, authentication, authorization, or not-found problems without a relevant user or state change.
- If a non-idempotent request times out after transmission, the client MUST treat the result as unknown and reconcile using an idempotency key or operation-status resource.
- Server and client timeouts MUST be bounded and documented by operation class; numeric targets remain `TBD` until FN-017/NFR-REL-001 decisions are approved.

### Rate limits

- Public and high-risk operations MUST have an approved rate-limit policy before production.
- Rate limiting MUST consider identity, operation risk, abuse patterns, and trusted network boundaries; IP address alone is insufficient identity.
- A limited request returns `429 Too Many Requests` with a safe problem body and `Retry-After` where possible.
- Limits and headers MUST NOT disclose sensitive anti-abuse thresholds when doing so would materially weaken protection.

## Compatibility and evolution

### Compatible changes

The following are generally compatible when existing semantics do not change:

- Adding an optional request property with a documented default.
- Adding a response property that clients are required to ignore when unknown.
- Adding a new endpoint.
- Adding an optional filter or sort option.
- Adding a new problem code for a circumstance previously represented by a documented broader problem, provided clients already handle the status generically.

### Breaking changes

The following require a new major version or a reviewed compatibility migration:

- Removing or renaming a field, endpoint, enum value, or supported behavior.
- Changing a field's type, format, meaning, nullability, unit, precision, or authorization visibility.
- Making an optional request field required.
- Changing default pagination, filtering, sorting, idempotency, or lifecycle semantics in a way that changes existing results.
- Reusing an error code for a different condition.
- Changing a success or error status in a way that invalidates documented client handling.

### Client tolerance

- Clients MUST ignore unknown response object properties unless the schema explicitly defines a closed security-sensitive object.
- Clients MUST NOT invent behavior for unknown enum values. Contracts MUST state whether an enum is open, requiring an “unknown” fallback, or closed, requiring a controlled compatibility failure.
- Servers MUST reject unknown request commands and security-sensitive values rather than guessing intent.

### Deprecation

- Deprecated behavior MUST be documented with replacement guidance, telemetry for remaining use, an owner, and an earliest removal date.
- Where supported, responses SHOULD include standards-based deprecation and sunset metadata.
- Removal MUST follow the approved support window and cannot rely solely on an undocumented client release assumption.

## Caching

- Authenticated or personal responses MUST default to `Cache-Control: no-store` unless a reviewed endpoint proves a safe, user-scoped caching policy.
- Shared caches MUST NOT store responses containing personal, KYC, location, financial, complaint, authentication, or emergency data.
- Public reference data MAY use explicit freshness and validators such as `ETag`.
- Cache keys MUST account for every request property and authorization dimension that changes the representation.
- A cache MUST NOT become the source of truth for domain state.

## Documentation requirements

Every endpoint specification MUST document:

- Purpose, caller roles, authorization and ownership policy.
- Method, path, media types, request schema, and response schemas.
- Success statuses and all expected problem codes.
- Validation, normalization, size, pagination, filtering, and sorting rules.
- Idempotency and concurrency behavior.
- Side effects, domain events, external calls, and audit expectations.
- Timeout, retry, rate-limit, caching, and eventual-consistency behavior.
- Sensitive fields, redaction, retention, and observability constraints.
- Compatibility classification and test requirements.

Schemas SHOULD be maintained in a machine-readable contract format once the backend toolchain is selected. Generated clients must be produced from the schema source and must not be hand-edited.

## Contract review checklist

- [ ] Resource and fields use the documented naming and representation rules.
- [ ] Authentication, authorization, ownership, and data minimization are explicit.
- [ ] Every input boundary has validation and size limits.
- [ ] Success and problem responses are documented and tested.
- [ ] Pagination and deterministic ordering exist for unbounded collections.
- [ ] Retry behavior is safe, bounded, and tied to idempotency.
- [ ] Concurrent updates cannot silently overwrite or duplicate effects.
- [ ] Correlation metadata is returned without carrying sensitive data.
- [ ] Compatibility and deprecation impact are reviewed.
- [ ] Logs, metrics, traces, and examples contain no credentials or personal data.
