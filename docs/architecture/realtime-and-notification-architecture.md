# Real-time and notification architecture

## Status and scope

This document defines FixNow's durable event flow, authenticated live delivery, provider presence, location updates, notification policy/delivery, failure behavior, privacy controls, and observability. It is normative architecture, not evidence that infrastructure or features exist.

Related decisions and contracts:

- [ADR-0006: Use transactional outbox events and WebSocket projections](decisions/0006-use-outbox-events-and-websocket-projections.md)
- [Event conventions](event-conventions.md)
- [API conventions](api-conventions.md)
- [Data architecture](data-architecture.md)
- [Identity and authorization](../security/identity-and-access.md)
- [Security and privacy architecture](../security/security-and-privacy-architecture.md)

The durable event broker/queue, hosted WebSocket service, push provider, SMS/email provider, exact retry/TTL/SLO limits, launch channels, quiet-hours policy, emergency override, and provider credentials remain unresolved. FCM is only a candidate in FN-061, not selected here.

## Architecture layers

```text
Domain command
  │ authorize + validate
  ▼
PostgreSQL transaction
  ├─ authoritative domain state
  └─ durable outbox integration event
          │ at-least-once publication
          ▼
Approved durable event transport (provider/technology TBD)
  ├─ domain consumers / projections
  ├─ notification policy → durable notification intent
  └─ live projection gateway
          │
          ├─ authenticated WebSocket → connected authorized client
          └─ provider adapter → push/SMS/email candidate channels

Client recovery always returns to authenticated HTTP snapshot/state APIs.
```

### Authority rules

- PostgreSQL domain state is authoritative. An event, WebSocket frame, push message, delivery receipt, cache entry, device notification, or client state cannot override it.
- Redis may hold reconstructable connection routing, presence, latest-location, deduplication acceleration, and rate data, but never durable booking/notification truth.
- Durable events announce committed facts through the transactional outbox. No best-effort “save then publish” sequence is allowed for facts required by downstream workflows.
- WebSocket and push delivery are projections. Clients reconcile with authenticated API snapshots after start, reconnect, gap, stale data, conflict, or notification open.
- Notification delivery is not proof that a person read, understood, or acted on information.

## Delivery guarantees

| Layer | Guarantee | Ordering | Recovery |
| --- | --- | --- | --- |
| Domain state + outbox | Atomic PostgreSQL commit | Transaction/domain invariant order | Database backup/restore and outbox recovery |
| Durable transport | At least once; delay/duplicates possible | Per aggregate when partitioned correctly; no global order | Consumer dedup, sequence/gap detection, reconciliation, replay |
| WebSocket live projection | Best effort while connected; duplicates/gaps/reorder possible across reconnect/instances | Per subscription/aggregate sequence when emitted; no global order | Bounded resume if available, otherwise HTTP snapshot and resubscribe |
| Push/SMS/email adapter | Best effort; provider acceptance/receipt is not user delivery | Not guaranteed | Intent retry until expiry, in-app/API authoritative state, alternate approved channel if policy allows |

- Exactly-once end-to-end delivery is not claimed.
- Numeric delay, retention, retry, replay, throughput, and availability targets remain `TBD` pending OD-012/OD-017/OD-018 and provider selection.
- Emergency or high urgency changes prioritization and fallback policy but does not turn an unreliable channel into guaranteed delivery.

## WebSocket connection lifecycle

### Connect and authenticate

1. Client obtains its current authoritative snapshot over the versioned HTTPS API.
2. Client opens a TLS-protected WebSocket to the approved endpoint.
3. The gateway authenticates a short-lived audience/environment-bound session using an approved handshake method that avoids credentials in URLs/logs.
4. The gateway resolves internal principal, actor context, account state, session revocation, connection quotas, and policy version.
5. The server confirms a connection ID, heartbeat policy, supported protocol version, maximum frame/subscription limits, and resume capability.

- TLS certificate validation is mandatory; no plaintext shared-environment socket.
- `Origin` is allowlisted for browser clients. CORS does not secure WebSockets.
- Authentication at connection time does not authorize a subscription or event.
- Long-lived sockets revalidate on credential/session expiry, role/account/provider-state change, and at a bounded interval. Revocation closes affected connections promptly.
- Credentials, device tokens, or sensitive resource IDs MUST NOT be placed in query strings, connection URLs, or logs.

### Subscribe

Client subscription request:

```json
{
  "type": "subscribe",
  "requestId": "req_opaque",
  "channel": "booking",
  "resourceId": "bkg_opaque",
  "afterSequence": 12
}
```

- Channels are allowlisted semantic resources, not arbitrary topic/room names supplied by clients.
- The backend authorizes principal, resource relationship, booking/provider/account state, field projection, and requested resume position for every subscription.
- Subscription authorization is re-evaluated on relevant state changes. Removed access unsubscribes/closes without continuing stale delivery.
- A caller authorized for one booking/provider does not gain list/discovery access to other channel names/IDs.
- Subscribe acknowledgements and denials use stable safe codes and do not reveal protected resource existence.

### Server frame

```json
{
  "type": "booking.projection-updated.v1",
  "eventId": "evt_opaque",
  "subscriptionId": "sub_opaque",
  "resourceId": "bkg_opaque",
  "sequence": 13,
  "occurredAt": "2026-08-09T12:30:00Z",
  "data": {
    "status": "provider-assigned"
  }
}
```

- Frames use minimal role/resource-specific projections, not internal integration-event payloads or database objects.
- `eventId` supports duplicate detection but is not authorization or receipt proof.
- `sequence` is monotonic within the subscribed aggregate/projection. Clients discard duplicates/stale frames and treat a gap as reconciliation-required.
- Frame schema/version follows compatibility rules; unknown major versions trigger controlled snapshot/update behavior, not guessed processing.
- Sensitive fields such as precise location use separate authorized frame types and lifecycle rules.

### Heartbeat, backpressure, and disconnect

- Protocol ping/pong or application heartbeat detects liveness at approved bounded intervals.
- Heartbeats contain no business/personal data and do not by themselves mark a provider available for matching.
- The server enforces connection, subscription, frame-size, message-rate, idle, lifetime/reauthentication, and outbound-buffer limits.
- A slow consumer does not cause unbounded memory. Coalescible state projections keep only the latest safe state; non-coalescible overflow closes with a retryable code and forces snapshot reconciliation.
- Invalid schema, unauthorized message, abuse, or limit violation receives a bounded response/close and security telemetry without echoing sensitive input.
- Graceful server drain stops new connections, signals retry where practical, and bounds shutdown. Clients reconnect with exponential backoff and jitter.

## Resume and reconciliation

- A resume token/cursor, if supported, is opaque, integrity-protected, principal/subscription/environment scoped, short-lived, and contains no personal data.
- Resume buffers are bounded. They are not durable event retention and do not promise replay after expiry, failover, deploy, or storage loss.
- Server accepts resume only if authorization still holds and the requested sequence remains safely available.
- If resume is impossible, authorization changed, a gap exists, or the client is uncertain, the server returns `snapshot-required` and the client:

  1. pauses dependent local actions,
  2. fetches the authorized HTTP resource snapshot,
  3. replaces/reconciles local state,
  4. subscribes from the returned version/sequence.

- Clients MUST NOT infer a missed booking/payment/emergency action solely from lack of frames.
- Offline commands use normal authenticated APIs and idempotency, not queued WebSocket frames, unless a later contract explicitly approves them.

## Provider presence

### State model

Presence concepts are distinct:

| Concept | Meaning |
| --- | --- |
| Connected | At least one recently healthy authenticated provider connection exists |
| Available | Provider deliberately enabled availability and satisfies schedule/verification/account policy |
| Busy | Provider has work/state that policy says prevents or limits matching |
| Offline/stale | No valid heartbeat or availability lease within the freshness window |

- Connected does not mean available; available does not guarantee current location, eligibility, assignment, or acceptance.
- Availability intent/state required for domain decisions is stored authoritatively according to FN-033. Redis holds only reconstructable presence/freshness leases.

### Presence lease

- A provider connection updates a Redis presence key with opaque provider/session references, state version, and TTL after authentication and policy checks.
- Every key is environment/domain/version namespaced and contains no phone, name, address, raw token, or coordinate.
- TTL, heartbeat, grace, multi-device aggregation, and offline-transition timing remain `TBD` and must be derived from matching accuracy, battery, scale, privacy, and outage targets.
- Disconnect is a hint; expiry determines stale/offline when a clean disconnect is absent.
- Multiple devices/connections have an explicit aggregation rule. One compromised/stale device cannot silently preserve availability forever.
- Redis loss marks presence unknown/offline for safety and rebuilds from live connections; it cannot corrupt durable provider state.
- Presence transitions may create coarse durable events when another domain requires them, but individual heartbeats are not durably published/logged.

## Live location

### Ingestion contract

A location update includes only fields required by the approved contract:

```json
{
  "sequence": 184,
  "capturedAt": "2026-08-09T12:30:00Z",
  "latitude": 22.3072,
  "longitude": 73.1812,
  "accuracyMeters": 18.0
}
```

- Backend authenticates provider/device session and validates provider/account/booking/consent/permission state, monotonic device-session sequence, timestamp skew, coordinate bounds, accuracy bounds, rate, and payload size.
- Server records/uses `receivedAt` separately and never presents client time as server truth.
- Plausibility/spoof signals route to approved trust review; they do not autonomously punish a provider.
- Precise updates are accepted only for an assigned provider after booking acceptance while the booking is in `On The Way` or the equivalent active-travel state. Online/available presence alone never authorizes continuous precise tracking.
- Background collection is permitted only during that active travel/service period when required for ETA/live tracking. The provider must first receive the approved versioned OD-010 notice and grant required consent/OS permission.
- Moving clients target a configurable 10–15-second update interval and reduce frequency while stationary where practical. Updates older than the configurable stale threshold, initially 60 seconds, are rejected or projected as unavailable for tracking/ETA.
- Accuracy/precision acceptance bounds, update interval, stale threshold, and cache retention are centralized configuration. They are enforced server-side as well as coalesced client-side.

### Storage and distribution

- Latest operational location is held primarily in Redis (or an equivalent approved ephemeral cache) with a strict TTL no longer than the stale threshold and is not authoritative historical state.
- Raw point/route history is prohibited for the MVP. Any future history requires an approved purpose, explicit retention/access/deletion rules, security/privacy/product review, and a separate tracker task/ADR if material.
- Matching SHOULD use the coarsest representation that meets approved accuracy. Exact customer/provider coordinates are not published in integration-event routing or telemetry.
- Exact location is available only to the provider, the customer assigned to the active booking, authorized backend/realtime services, and narrowly authorized, audited support/admin personnel for an operational need. It is never available to unrelated customers or providers, and access ends immediately when state, assignment, permission, or consent changes.
- WebSocket location frames include captured/received time, freshness/accuracy, and per-stream sequence so clients can show stale/unknown honestly.
- ETA is a separate estimate with provider/time/source freshness and unavailable state; it is never guaranteed.

### Load and privacy controls

- Clients coalesce movement and apply minimum distance/time/accuracy rules selected by FN-044. Server independently rate-limits and may drop redundant stale points.
- Backpressure favors latest authorized state over a backlog of obsolete points.
- Do not log raw coordinates/routes, include them in event/topic/key names, push payloads, crash reports, analytics, or unrestricted support views.
- Consent/permission withdrawal stops transmission immediately, invalidates active location, and projects “Live location unavailable” without automatically cancelling the booking. Manual status controls and call/chat/service workflows remain available where possible.
- Collection/distribution and cached precise location stop/delete on consent or permission withdrawal, applicable provider offline state, booking cancellation/completion, arrival, or any end of active travel/tracking. App background stops collection unless the active-job background authorization applies; logout, suspension, and expiry always revoke access.
- Google Maps Platform is the initial maps/navigation provider under ADR-0012 and must be accessed through a replaceable adapter with minimized, purpose-bound data.

## Notification architecture

### Channel roles

| Channel | Intended role | Delivery truth |
| --- | --- | --- |
| In-app/API state | Authoritative current/historical product state when fetched from backend | Source of truth |
| WebSocket | Low-latency update for active authorized sessions | Best effort; reconcile via API |
| Mobile push | Wake/alert a device with privacy-safe content | Best effort; provider acceptance is not user receipt |
| SMS/email | Candidate fallback or verified communication where product/legal policy approves | Best effort; provider receipt/read semantics vary |

- A channel is enabled only after provider, cost, privacy/legal, consent/preference, abuse, template, retention, and incident review.
- Critical or emergency classification may change priority/fallback/quiet-hours behavior only under approved policy. It never guarantees human response.

### Intent pipeline

1. A validated durable domain event becomes available at least once.
2. Notification policy evaluates current authoritative audience relationship/state, template eligibility, preferences/consent, quiet hours, urgency, prior intents, and expiry.
3. It atomically creates/deduplicates a durable notification intent and per-channel delivery records in PostgreSQL.
4. Channel workers claim due attempts, recheck revocation/expiry and material authorization where required, render the approved localized template, and call a provider adapter.
5. Provider response maps to a stable internal outcome; transient failure schedules bounded retry, invalid endpoint disables it, permanent failure terminates, and ambiguous outcomes reconcile where possible.
6. Outcomes feed privacy-safe telemetry and any approved alternate-channel policy.

- Domain-event retries MUST NOT create duplicate intents. The deduplication key includes event/intent policy, audience, template purpose/version, and channel as appropriate.
- Delivery records never alter authoritative booking/payment/provider state.
- A provider message ID is reconciliation metadata, not proof of human delivery or authorization.

### Device/endpoints

- Device endpoint registration requires an authenticated principal, app/environment/platform, opaque installation ID, provider token validation, and replacement/revocation lifecycle.
- Provider tokens are confidential bearer-like routing data: encrypt/protect, restrict access, exclude from logs/analytics, never expose to other users, and delete promptly when invalid, logout/account deletion, or retention policy requires.
- One installation may rotate tokens; one token must not remain bound to multiple unrelated principals/environments.
- Sending rechecks endpoint ownership/status to prevent notifications reaching a recycled/shared device after logout/account switch.
- Topic/broadcast subscription at a provider MUST NOT replace backend audience authorization for private events.

### Templates and content privacy

- Templates are versioned source artifacts with stable keys, purpose, owner, supported locale, variables, classification, preview tests, and channel limits.
- Server renders from allowlisted typed variables. Domain/customer text is not used as template markup, deep-link code, or provider configuration.
- Default lock-screen content is generic for booking, location, KYC, payments, complaints, emergency, and other sensitive classes, for example “FixNow has an update.”
- Push payloads contain an opaque intent/resource reference and minimal routing metadata, not precise location, phone/address, KYC/evidence, payment amount/provider payload, complaint allegation, OTP/token, or emergency details.
- Opening a deep link starts the app and re-authenticates/re-authorizes current resource state. A message cannot grant access or execute a consequential action.
- Localization preserves safety/legal meaning and variable encoding. Missing locale falls back to an approved default, not raw internal text.

### Preferences, mandatory messages, quiet hours

- Preferences are purpose/channel specific, versioned, auditable, and enforced server-side. OS channel settings are additional constraints, not the preference source of truth.
- Marketing/promotional messaging, if ever approved, is separate from transactional/service/safety purposes and defaults according to applicable policy.
- Mandatory service/security/legal messages require documented necessity/basis and still minimize channel/content; “mandatory” is not a way to bypass consent policy.
- Quiet hours use the user's approved timezone and daylight-saving behavior. Missing/invalid timezone uses a documented safe default or defers non-urgent delivery.
- Emergency/high-priority quiet-hours override requires legal/safety/product approval, rate/abuse limits, explicit templates, and audit.

## Retry, expiry, deduplication, and fallback

### Attempt lifecycle

| State | Meaning |
| --- | --- |
| Pending | Intent/attempt is eligible but not claimed |
| In progress | Worker holds a bounded lease |
| Deferred | Waiting for quiet hours, provider backoff, transient failure, or policy time |
| Accepted | Provider accepted the request; not proof of device/user delivery |
| Delivered/read | Recorded only when a channel supplies trustworthy semantics; meaning documented per provider |
| Failed permanent | Provider/policy says retry will not succeed without change |
| Expired | Usefulness deadline passed; no more delivery |
| Suppressed | Preference, dedup/collapse, authorization/state, or policy prevented send |
| Quarantined | Invalid configuration/template/data or repeated unsafe failure needs operator action |

- Attempts have opaque IDs, intent ID, channel, endpoint reference, template version, due/expiry times, attempt count, stable outcome code, and provider message reference where needed.
- Retry only transient mapped outcomes with exponential backoff, jitter, provider `Retry-After`, bounded attempts, and absolute expiry/age.
- Permanent invalid token/address disables/removes the endpoint under policy; it is not retried indefinitely.
- Unknown/ambiguous provider outcome is reconciled when supported and MUST NOT cause an unsafe duplicate for non-repeatable channels.
- Worker leases recover after crash; the attempt remains idempotent and duplicates are tolerated.
- Quarantine/dead-letter data is minimal, restricted, retention-bounded, alerted, and replayed only through audited approved tooling.

### Collapse and order

- Notification order is not guaranteed across workers, channels, devices, providers, retries, or offline delivery.
- State-like updates MAY collapse to the newest intent using an approved key, but transition facts that require separate user awareness cannot be silently collapsed.
- Template/deep link always causes current authoritative state fetch, so a late older notification cannot reverse client state.
- User-visible timestamps distinguish event occurrence from delivery time where meaningful.

### Fallback

- Primary fallback is authoritative in-app/API state and an honest unread/failed notification status for operations—not pretending delivery succeeded.
- Alternate channel fallback is allowed only for an approved purpose/audience, user preference/consent/legal basis, verified endpoint, content-minimization template, cost/abuse limit, and expiry.
- Provider-wide outage can disable a channel, defer within usefulness, use an approved alternate, or expose in-app state. It cannot bypass authorization/privacy or spam all channels.
- No-provider/no-network/denied-permission/device-offline outcomes are expected and tested.

## Security and abuse controls

- Authenticate and authorize connection, subscription, publish/admin action, endpoint registration, template/configuration change, quarantine/replay, and restricted telemetry access separately.
- Only backend domains create integration events and notification intents; clients cannot publish arbitrary events or choose another principal's audience/address.
- Enforce connection/subscription/message/update/registration/send limits by appropriate principal, installation, resource, operation, and risk signals.
- Protect against channel/topic guessing, cross-booking subscription, endpoint reassignment, replay, forged receipts/webhooks, provider callback spoofing, template injection, deep-link injection, and notification bombing.
- Provider callback authenticity uses signature/authentication, time/replay checks, schema/size limits, idempotency, and safe status mapping.
- Administrative broadcast/export/replay requires separate narrow permission, bounded audience/time, preview/dry run, approval for high impact, kill switch, and audit.
- Do not expose provider credentials, device tokens, socket auth, resume tokens, payloads, precise location, or personal identifiers in logs/metrics/errors.

## Failure modes

| Failure | Required behavior |
| --- | --- |
| PostgreSQL commit succeeds, transport unavailable | Outbox remains pending; alert on age; publisher retries; domain state remains committed |
| Duplicate/out-of-order durable event | Consumer deduplicates, checks aggregate sequence, reconciles gap/stale state |
| Poison event/schema mismatch | Stop unsafe processing, quarantine minimally, alert owner, do not block unrelated partitions where adapter permits |
| Redis loss/failover | Presence/latest location becomes unknown/stale; routing rebuilds; durable state unaffected; prevent fallback overload |
| WebSocket gateway restart/partition | Connections drop/reconnect with jitter; authorize again; resume if safe or require snapshot |
| Slow/abusive client | Coalesce safe state, enforce buffers/rates, close and require snapshot; protect other clients |
| Authorization/session/provider state changes | Revoke connection/subscription/endpoints as policy requires; stop restricted delivery |
| Push/provider outage/rate limit | Bounded retry/defer to expiry, circuit/load protection, approved fallback, visible operational alert |
| Invalid/recycled endpoint | Disable binding, stop retries, require authenticated re-registration |
| Late notification | Open fetches current state; expired intents do not deliver; old message cannot execute action |
| Monitoring/control outage | Fail closed for protected/replay/admin paths; surface degraded state; no silent bypass |

## Observability and operations

### Metrics

- Outbox pending age/count, publish attempts/latency/failure/quarantine.
- Durable consumer lag, throughput, duplicates, gaps, retries, poison/quarantine, replay.
- WebSocket active connections/subscriptions by bounded dimensions, auth/subscription denials, reconnects, resume success/snapshot required, disconnect reason, buffer pressure, frame latency/age.
- Presence heartbeat age, stale/offline transitions, Redis errors/eviction, rebuild duration.
- Location update accepted/dropped/stale/rate-limited counts, end-to-end age and distribution latency without coordinates/provider identity labels.
- Notification intents created/suppressed/expired, attempt latency/count/outcomes, invalid endpoint rate, provider throttling/outage, quiet-hour queue age, quarantine, fallback use, estimated cost.

### Alerts and runbooks

- Owners define thresholds after scale/SLO/provider decisions; alerts cover delayed outbox/consumers, sequence gaps, socket auth/revocation failures, abnormal subscription denial/connection churn, stale presence/location, provider outage/throttle, invalid-token spike, quarantine growth, and unexpected send volume/cost.
- Every alert has owner, severity, user impact, privacy-safe diagnostic queries, mitigation/kill switch, recovery/replay/reconciliation, and validation steps.
- Replays, bulk broadcasts, channel disable/fallback, provider credential rotation, endpoint purge, and restricted quarantine inspection require audited runbooks.
- Dashboards and traces exclude event/message bodies, tokens, coordinates, contact data, and high-cardinality personal/resource labels.

## Validation requirements

### Durable events

- Atomic state/outbox transaction, publisher crash/lease recovery, transport outage, duplicate publication, ordering partition, schema rejection, poison/quarantine, consumer dedup, gap/stale detection, replay bounds, and compatibility migration.

### WebSocket

- TLS/origin/auth, expiry/revocation, every allowed/denied subscription relationship/state, cross-user/resource guessing, reconnect/resume/gap/snapshot, duplicate/out-of-order, backpressure/slow client, heartbeat, limits/abuse, deploy/drain, gateway/Redis outage, and field redaction.

### Presence/location

- Multi-device aggregation, clean/unclean disconnect, TTL expiry, Redis loss, unavailable/verified-state change, sequence/skew/rate/accuracy/spoof signals, consent/permission withdrawal, booking end, stale/offline display, no coordinate telemetry, and privacy deletion.

### Notifications

- Event-intent dedup, audience authorization, preference/quiet hours/override, endpoint registration/rotation/reassignment/revocation, generic sensitive templates, localization/encoding, deep-link reauthorization, transient/permanent/ambiguous provider outcomes, backoff/expiry, collapse/order, alternate fallback, webhook authenticity/replay, quarantine/replay, provider outage, notification bombing, and cost limits.

## Decision and implementation gates

- FN-043 implements authenticated WebSocket infrastructure under this contract.
- OD-010 was approved on 2026-08-13. FN-044 may implement provider presence/live-location ingestion under that policy and ADR-0012, subject to its focused security/privacy validation.
- FN-045 implements booking tracking/ETA/event projections.
- FN-061 selects and integrates the push provider; FCM remains a candidate until its ADR/configuration review.
- FN-062 maps approved domain events to booking/provider/reminder/emergency notification policies.
- FN-063/FN-064 must approve emergency safety/legal behavior before critical notification override is enabled.
- Durable event transport selection requires a new ADR covering guarantees, partitions, retention/replay, security/privacy, operations, license, hosting, cost, and exit strategy.

## Primary references

- [RFC 6455: The WebSocket Protocol](https://www.rfc-editor.org/rfc/rfc6455)
- [CloudEvents specification](https://github.com/cloudevents/spec)
- [Firebase Cloud Messaging message handling](https://firebase.google.com/docs/cloud-messaging/receive-messages)
- [Apple local and remote notification programming guide](https://developer.apple.com/documentation/usernotifications)

Provider references explain channel limitations and are not provider-selection decisions.
