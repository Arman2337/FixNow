# ADR-0006: Use transactional outbox events and WebSocket projections

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering

## Context

FixNow requires durable facts for cross-module workflows and notifications, low-latency booking/location updates for active clients, and best-effort alerts for offline devices. A database commit followed by direct best-effort publish can lose events. A live socket or push receipt cannot be authoritative because clients disconnect, providers delay/drop/reorder messages, and retries duplicate delivery.

Current requirements establish PostgreSQL as the transactional authority and Redis as disposable ephemeral state. They do not yet establish launch scale, cloud/provider, durable broker, hosted WebSocket platform, push provider, retention, or SLO/cost targets.

## Decision

Adopt a layered event/delivery architecture:

1. Authoritative domain state and an integration-event outbox record commit atomically in PostgreSQL.
2. Outbox publishers deliver versioned minimal events to an approved durable transport with at-least-once semantics.
3. Consumers are idempotent, deduplicate by event/operation identity, and use per-aggregate monotonic sequence for gap/stale/order handling. No global order or exactly-once delivery is promised.
4. Authenticated WebSockets deliver low-latency authorized projections to connected clients. Resume is bounded; HTTP snapshot reconciliation is always the recovery authority.
5. Redis stores only reconstructable connection routing, presence, and latest operational location with explicit TTL.
6. Notification policy converts durable facts into deduplicated durable intents. Push/SMS/email adapters are best effort, expiry-bound, preference/purpose controlled, and never domain authority.
7. Event, projection, presence/location, and notification rules follow [`../event-conventions.md`](../event-conventions.md) and [`../realtime-and-notification-architecture.md`](../realtime-and-notification-architecture.md).

This ADR does not select a broker/queue, hosted real-time platform, push/SMS/email provider, framework/library, cloud, or exact retention/retry/SLO values.

## Consequences

### Positive

- Transactional outbox closes the state-commit/publish loss window without a distributed transaction.
- At-least-once plus explicit idempotency reflects realistic transport/provider behavior.
- Per-aggregate sequences allow bounded ordering checks without pretending a global clock/order.
- WebSocket projections provide low latency while HTTP snapshot recovery prevents socket state from becoming authority.
- Durable intents separate domain facts and audience policy from vendor payloads and channel outages.
- Provider/transport choices remain behind adapters until scale, region, reliability, privacy, and cost are known.

### Costs and risks

- Outbox publication, consumer deduplication, gap recovery, quarantine, replay, and schema governance add storage and operational complexity.
- PostgreSQL outbox load and cleanup require measurement/index/retention discipline.
- WebSocket connection routing, backpressure, reauthorization, deploy drain, and reconnect storms require careful capacity/operations.
- Notification preference, endpoint lifecycle, templates, retries, collapse, fallback, and provider reconciliation create a separate durable workflow.
- At-least-once designs cause duplicate/out-of-order attempts by nature; every consumer must be tested rather than assuming transport magic.

### Privacy and operations

- Events, routing metadata, presence/location, notification intents, device endpoints, quarantine, replays, and provider dashboards can create sensitive copies. Payload minimization, opaque routing, classification, access, retention/deletion, and telemetry controls apply at every layer.
- Operations owns outbox/consumer lag, quarantine, replay, WebSocket capacity/revocation, Redis loss, endpoint purge, provider outage, notification cost, and incident runbooks.
- Provider acceptance or socket send is not proof of human delivery; product and emergency UX must communicate uncertainty honestly.

## Alternatives considered

### Publish directly after database commit

Simpler code leaves a crash/failure window where state commits but required events/notifications are lost. Retrying the command may also duplicate domain effects.

### Distributed transaction across database and broker

This couples technologies and operations and is rarely supported end to end, especially with provider notification channels. The outbox contains the consistency boundary in PostgreSQL.

### Use Redis pub/sub or WebSockets as durable event transport

These are appropriate for ephemeral low-latency delivery but do not provide the required durable recovery/replay authority under the approved Redis role and disconnected clients.

### Push notifications as booking state delivery

Push can be delayed, collapsed, reordered, disabled, or dropped, and a provider receipt does not prove user delivery. It remains an alert/wake channel only.

### Polling only

Polling simplifies connection infrastructure and remains the recovery/fallback path, but can provide poor latency/battery/load behavior for active booking/location experiences. WebSockets are selected for active low-latency projections, with polling/snapshot fallback.

### Select a broker or hosted real-time/push provider now

Scale, availability, region/residency, deployment platform, budget, and provider requirements are unresolved. Selection now would be premature vendor coupling; a later ADR must use measured/approved requirements.

## Validation

- Prove state and outbox atomicity, publisher claim/crash recovery, at-least-once duplicates, per-aggregate ordering/gaps, idempotent consumers, quarantine, replay, and schema compatibility.
- Prove WebSocket authentication, per-subscription authorization, revocation, reconnect/resume/snapshot, duplicate/gap/order handling, backpressure, deploy drain, and Redis/gateway failure.
- Prove presence/location TTL, stale/offline behavior, consent/state changes, no raw telemetry leakage, and Redis loss recovery.
- Prove notification intent deduplication, endpoint ownership/lifecycle, preference/quiet-hours policy, privacy-safe templates, retry/expiry/fallback, webhook authenticity, provider outage, and deep-link reauthorization.
- Reconsider if measured scale, latency, ordering, retention/replay, multi-region, provider, cost, or operational constraints cannot be met safely by the selected implementations.
