# Event conventions

## Status and scope

These conventions define FixNow's durable integration-event contracts. They apply to events crossing module/process boundaries and to notification intents derived from domain facts. Internal in-process domain objects may use private representations but MUST map explicitly to these contracts at the boundary.

WebSocket projections and provider notification payloads are delivery representations, not durable domain-event contracts. See [Real-time and notification architecture](realtime-and-notification-architecture.md) and [ADR-0006](decisions/0006-use-outbox-events-and-websocket-projections.md).

No event broker, hosted WebSocket platform, or notification vendor is selected by this document.

## Event categories

| Category | Purpose | Durability | Examples |
| --- | --- | --- | --- |
| Domain event | Private fact used inside one domain consistency boundary | Domain-owned | Booking accepted inside booking module |
| Integration event | Minimal versioned fact published for other modules/services | Durable, at-least-once | Booking status changed, provider verification changed |
| Notification intent | Policy-approved request to notify an audience about a fact | Durable until terminal delivery policy | Notify assigned provider of eligible request |
| Live projection | Authorized low-latency view update for a connected client | Ephemeral; recover via snapshot | Booking status projection, latest provider position |
| Audit event | Security/accountability evidence | Durable under audit policy; separate schema/access | Privileged refund approved |

- Integration events announce facts that already committed. They MUST NOT be commands disguised as past-tense events.
- Audit events and integration events may share correlation metadata, but one MUST NOT substitute for the other's retention, integrity, or access controls.
- Raw high-frequency telemetry such as every GPS heartbeat is not a durable integration event by default.

## Envelope

Every integration event uses this logical envelope:

```json
{
  "specVersion": "1.0",
  "id": "evt_opaque",
  "type": "com.fixnow.booking.status-changed.v1",
  "source": "fixnow://backend/bookings",
  "subject": "booking/bkg_opaque",
  "occurredAt": "2026-08-09T12:30:00Z",
  "publishedAt": "2026-08-09T12:30:01Z",
  "aggregate": {
    "type": "booking",
    "id": "bkg_opaque",
    "sequence": 7
  },
  "correlationId": "2d41c4d8-46aa-4dd4-9e89-9bd0a06cb83e",
  "causationId": "cmd_opaque",
  "dataClassification": "confidential",
  "data": {
    "status": "provider-assigned"
  }
}
```

### Required envelope fields

| Field | Rule |
| --- | --- |
| `specVersion` | Envelope version. `1.0` identifies the initial FixNow envelope; it is separate from event data version. |
| `id` | Globally unique opaque event occurrence ID. Consumers use it for deduplication, not authorization. |
| `type` | Stable reverse-DNS event name ending in a major schema version. |
| `source` | Stable URI-like identifier for the publishing domain, not a host, pod, database, or vendor identifier. |
| `subject` | Opaque resource type/reference. It MUST NOT contain personal data or a provider URL. |
| `occurredAt` | RFC 3339 UTC instant at which the authoritative fact committed or became true. |
| `publishedAt` | RFC 3339 UTC instant at which the outbox publisher emitted this attempt. It may be later than `occurredAt`. |
| `aggregate` | Aggregate type, opaque ID, and positive monotonic per-aggregate sequence. |
| `correlationId` | Safe opaque request/workflow correlation value; it is not identity or idempotency proof. |
| `causationId` | Opaque identifier of the command/event that directly caused this fact. |
| `dataClassification` | Highest classification in `data`: `public`, `internal`, `confidential`, or `restricted`. |
| `data` | Minimal schema-validated event payload. |

- Optional trace context stays separate from business data and follows W3C Trace Context/security policy.
- Producer deployment, hostname, IP, framework exception, database ID, token, phone, email, address, or precise location MUST NOT appear in envelope metadata.
- Event time is not inferred from delivery time.

## Naming and schemas

Event types use:

```text
com.fixnow.{domain}.{past-tense-fact}.v{major}
```

Examples:

```text
com.fixnow.booking.created.v1
com.fixnow.booking.provider-assigned.v1
com.fixnow.provider.verification-changed.v1
com.fixnow.payment.transaction-verified.v1
```

- Names describe completed facts, not desired actions: `booking.cancelled`, not `booking.cancel`.
- One type has one owning domain and one machine-readable schema source after the shared-contract toolchain is chosen.
- Producers validate before writing/publishing; consumers validate before processing.
- Unknown fields in an existing major version are ignored by tolerant consumers unless the schema marks a closed security-sensitive object.
- Enums declare whether they are open or closed. Open enums require a safe unknown path; closed unknowns stop processing and quarantine safely.
- Payloads use the JSON naming, timestamp, money, identifier, and null/missing rules from [API conventions](api-conventions.md).

## Payload design and privacy

- Publish the minimum fact required by approved consumers, not a database row, API response, aggregate snapshot, third-party payload, or internal model.
- Consumers needing current/expanded data call an authorized API or maintain a documented projection; the event does not grant access.
- Prefer opaque IDs and coarse state. Do not include contact data, raw descriptions, private notes, KYC, signed URLs, complaint evidence, payment-provider payloads, auth material, full location, or AI prompts/output unless a reviewed consumer purpose makes it unavoidable.
- A restricted event requires named consumers, field-level purpose, encryption/access boundary, retention, replay controls, and focused security/privacy review.
- Event stores, broker retention, dead-letter/quarantine, observability, and replay environments inherit the payload classification.
- Deletion/rights workflows must cover event-derived projections and consumer stores. Durable event history is not permission for indefinite personal-data retention.
- Never use sensitive data in topic/stream names, partition keys, subscription names, routing keys, metric labels, or log fields.

## Delivery semantics

### Producer

1. Validate a domain command and authorization.
2. Commit authoritative state and an outbox record in one PostgreSQL transaction.
3. A publisher claims pending outbox records safely, validates the integration schema, and sends them to the approved durable transport.
4. Mark/record publication only after transport acknowledgement under the selected adapter semantics.
5. Retry transient publication failures with bounded backoff and jitter; permanent schema/configuration failures enter an operator-visible quarantine.

- Exactly-once end-to-end delivery is not promised.
- Outbox rows are retained long enough for recovery and evidence, then removed under an approved operational retention policy.
- Multiple publisher instances cannot concurrently corrupt or skip a record; lease/claim recovery is tested.
- A commit without immediate publication is expected delay, not rollback of the committed fact.

### Consumer

- Delivery is at least once. Every consumer MUST be idempotent.
- Consumers persist the event ID or another atomic deduplication record with their side effects when duplicate effects would matter.
- A duplicate returns success after confirming the prior compatible result; it is not re-executed.
- Consumers validate envelope/schema, allowed source/type/version, classification, and required authorization context before side effects.
- Transient failures retry with bounded backoff/jitter and attempt/age limits. Permanent poison messages enter a restricted quarantine/dead-letter workflow with alert and runbook.
- A consumer MUST NOT silently discard an unknown major version, invalid restricted event, exhausted retry, or quarantine backlog.
- Replay uses the same validation/idempotency paths, a declared bounded scope, approved operator, audit, rate controls, and downstream-impact review.

## Ordering and concurrency

- FixNow guarantees no global event order.
- A producer assigns a strictly increasing sequence within one aggregate transaction boundary.
- The selected transport SHOULD preserve order per aggregate partition, but consumers MUST still detect duplicates, gaps, stale sequences, and concurrent delivery.
- A sequence lower than or equal to the last applied sequence is duplicate/stale and must not reverse state.
- A sequence gap pauses order-sensitive application and triggers bounded retry/reconciliation from authoritative state or a documented gap-recovery path.
- Events across aggregates may arrive in any order. Workflows needing multi-aggregate consistency require explicit orchestration/saga rules and compensation; timestamp sorting is not sufficient.
- `occurredAt` is for business/audit context, not a total-order clock.

## Compatibility and lifecycle

Compatible within a major event type:

- Add an optional field with a documented default/absence behavior.
- Add a new event type.
- Broaden safe human documentation without changing machine semantics.

Breaking changes require a new `.v{major}` type:

- Remove/rename a field or type.
- Change type, format, nullability, unit, precision, classification, authorization visibility, or semantic meaning.
- Make an optional field required.
- Change aggregate identity/sequence or delivery assumptions.
- Reinterpret an enum value or event fact.

For a major migration:

1. Publish new consumer schemas and compatibility tests.
2. Deploy consumers that handle both versions or a reviewed translation adapter.
3. Dual-publish only for a bounded observed migration period when side effects remain deduplicated across versions.
4. Stop old publication after consumer/retention evidence.
5. Retire old consumers/schema only after replay and rollback windows expire.

An accepted event contract is never edited to hide historical semantics.

## Notification intents

A notification intent is a durable event with a policy-specific payload, for example:

```json
{
  "intentId": "nti_opaque",
  "eventId": "evt_opaque",
  "audience": {
    "principalId": "usr_opaque"
  },
  "template": {
    "key": "booking-provider-assigned",
    "version": 2
  },
  "urgency": "normal",
  "expiresAt": "2026-08-09T12:45:00Z",
  "deepLink": {
    "route": "booking-detail",
    "resourceId": "bkg_opaque"
  }
}
```

- The intent references a reviewed template; it does not carry rendered sensitive text by default.
- Audience derives from authoritative relationships and current policy, never from an arbitrary client-provided address/token.
- `urgency` is one of `low`, `normal`, `high`, or `critical`; critical use requires an approved domain policy and does not guarantee delivery.
- `expiresAt` bounds usefulness and retry. Expired intents stop delivery and record the terminal outcome.
- Deep links contain opaque route/resource references and re-authorize on open. They carry no token or sensitive state.
- One domain event may produce zero or more intents according to consent/preferences, lifecycle, quiet hours, safety overrides, duplication/collapse, and channel availability.

## Observability and audit

Measure by bounded dimensions:

- Outbox pending age/count, claim recovery, publish latency, attempts, failures, and quarantine count/age.
- Consumer lag, throughput, attempt age, duplicates, sequence gaps, invalid schema/source, poison/quarantine, and replay activity.
- Notification-intent creation/suppression/expiry and delivery outcomes by approved channel/provider status class.

Telemetry MUST NOT include payloads, device tokens, signed URLs, exact subjects with personal meaning, contact data, precise location, or unrestricted high-cardinality IDs. Restricted quarantine access is purpose-bound and audited.

Every event type has an owner, schema, classification, producers, consumers, retention/replay needs, ordering key, idempotency strategy, failure runbook, SLO/alert targets when approved, and compatibility tests.

## Event contract review checklist

- [ ] The type is a committed fact with one owner and versioned schema.
- [ ] Payload is minimal, classified, authorized by purpose, and free of secrets/provider internals.
- [ ] State and outbox commit atomically.
- [ ] Delivery is treated as at least once; consumer idempotency and deduplication are explicit.
- [ ] Per-aggregate sequence, duplicate, gap, stale, and cross-aggregate ordering behavior are tested.
- [ ] Retry, expiry, quarantine, replay, retention, and operator ownership are documented.
- [ ] Compatibility/migration and deletion/derived-data impact are reviewed.
- [ ] Telemetry is useful without becoming a payload copy.
