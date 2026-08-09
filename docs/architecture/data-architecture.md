# Data and storage architecture

## Status and scope

This document defines FixNow's persistence, cache, object-storage, migration, retention, backup, and recovery conventions. It is normative for future implementation but does not provision a service, select a cloud vendor, choose an ORM, or prove that any data capability exists.

The core decisions are recorded in:

- [ADR-0002: Use PostgreSQL as the transactional system of record](decisions/0002-use-postgresql-system-of-record.md)
- [ADR-0003: Use Redis for ephemeral cache and coordination](decisions/0003-use-redis-ephemeral-cache.md)
- [ADR-0004: Store binary artifacts in private object storage](decisions/0004-use-private-object-storage.md)

Product retention, residency, launch jurisdiction, recovery targets, and hosted providers remain open decisions in [product requirements](../product/requirements.md). Those values must be approved before production configuration.

## Data-store roles

| Capability | Approved role | Must not become |
| --- | --- | --- |
| PostgreSQL | Authoritative transactional records, relationships, invariants, lifecycle state, metadata, audit references, idempotency records | An unbounded binary store, analytics warehouse, search engine by default, or cross-module dumping ground |
| Redis | Disposable cache, rate-limit counters, short-lived presence, bounded coordination, and other reconstructable ephemeral state | The only copy of a booking, identity, payment, verification decision, audit event, or other durable fact |
| Private object storage | Encrypted storage for approved binary artifacts such as provider documents, issue media, and generated invoice files | A public file server, authorization authority, mutable domain database, or store for secrets embedded in object names |

PostgreSQL is the source of truth whenever stores disagree. Redis entries and materialized object-derived data must be rebuilt or reconciled from authoritative records and approved external sources.

## Data ownership and boundaries

- Each domain module owns its tables, migrations, repositories, retention behavior, and documented read/write interfaces.
- A module MUST NOT write another module's tables directly. Cross-module changes use an explicit domain interface or a documented transaction orchestration boundary.
- Database schemas or naming prefixes SHOULD make ownership visible once the backend module structure is selected.
- Cross-application access occurs through documented APIs/events. Mobile, admin, AI, and infrastructure code MUST NOT connect directly to the application database.
- Reporting queries MUST NOT become hidden write dependencies. Production analytics extraction requires a separate reviewed design when scale and privacy requirements are known.
- Stable shared contracts belong in `shared/`; database entities and ORM models remain private to `backend/`.
- External provider identifiers are stored as data with explicit provider/type context and are never treated as internal authorization proof.

## PostgreSQL conventions

### Modeling

- Use normalized relational tables for authoritative domain state unless a documented access pattern justifies another representation.
- Enforce invariants at the strongest practical layer: database constraints for structural truth and domain logic for contextual policy. Critical rules SHOULD have defense in depth where race conditions are possible.
- Define primary keys, foreign keys, nullability, unique constraints, and check constraints explicitly.
- Internal identifiers MUST be opaque to API clients. The implementation task will choose the exact identifier strategy and document collision, index-locality, and information-leak tradeoffs.
- Store timestamps as timezone-aware instants normalized to UTC. Store a separate timezone/locale only when business interpretation requires it.
- Store calendar dates separately from instants when no time-of-day is intended.
- Store money as integer minor units with an ISO 4217 currency code unless the approved payment contract requires a stricter fixed-precision representation.
- Store geographic data only at the precision and duration required by approved location policy. A geospatial extension requires a separate documented need and migration plan.
- JSON columns MAY hold bounded, schema-validated attributes whose relational shape is genuinely variable. They MUST NOT bypass ownership, compatibility, indexing, retention, or sensitive-field controls.
- Enumerated domain states SHOULD use constraints or reference data that support deliberate evolution. Database-native enum types require a migration rationale because removal/reordering can be operationally costly.

### Transactions and concurrency

- A transaction boundary MUST align with one domain consistency boundary; network calls MUST NOT remain inside a database transaction unless a reviewed protocol makes that unavoidable.
- Booking assignment, lifecycle transitions, financial state, verification decisions, and idempotency claims MUST use atomic database invariants appropriate to their race conditions.
- Use the least restrictive isolation level that preserves the documented invariant, then prove behavior with concurrent integration tests.
- Lock acquisition order MUST be consistent for multi-row workflows to reduce deadlocks.
- Deadlocks and serialization failures MAY be retried only with bounded attempts and when the whole transaction is safe to repeat.
- Optimistic concurrency versions SHOULD protect user-facing updates from lost writes. HTTP preconditions follow the [API conventions](api-conventions.md).
- Cross-store updates use an outbox or another reviewed durable handoff pattern; they MUST NOT rely on an uncoordinated database commit followed by a best-effort external call.

### Access and query safety

- Use parameterized access through the selected maintained database library. Dynamic identifiers and sort/filter fields must be allowlisted.
- Application roles receive only required connect, schema, table, sequence, and function permissions. Migration credentials are separate from runtime credentials.
- Administrative/manual database access must be time-bounded, audited, and unavailable to ordinary application code.
- Every unbounded collection requires pagination and deterministic ordering.
- New indexes require a demonstrated query/invariant need and review of write, storage, lock, and privacy costs.
- Query plans for high-volume or sensitive operations must be tested with representative, non-production-sensitive data.
- Database errors are mapped to safe domain/API problems and must not leak SQL, schema names, values, or connection details.

## Redis conventions

### Allowed uses

- Cache-aside entries for expensive reconstructable reads.
- Rate-limit and abuse-control counters with documented scope and expiry.
- Short-lived provider presence and freshness markers.
- Bounded idempotency acceleration only when the durable idempotency outcome remains in PostgreSQL for consequential operations.
- Carefully reviewed coordination primitives where loss is survivable and correctness is protected by an authoritative database invariant or fencing token.

Queues, durable event logs, task scheduling, and pub/sub delivery guarantees are not selected by this decision. FN-015 must decide event and real-time transport separately.

### Keys and values

- Keys use a versioned namespace: `fixnow:{environment}:{domain}:{purpose}:v{schema}:{opaque-id}`.
- Keys MUST NOT contain phone numbers, email addresses, names, raw addresses, precise coordinates, tokens, document names, or other sensitive/business-readable data.
- Every cache, presence, counter, lock, and temporary key MUST have an explicit TTL unless a reviewed platform key is intentionally persistent.
- TTLs derive from freshness, abuse, privacy, and recovery requirements; they are not arbitrary defaults. Production values remain `TBD` until owning tasks define them.
- Values are bounded, schema-versioned, and contain only the minimum reconstructable data.
- Bulk key scans in request paths are prohibited. Code must not depend on `KEYS`-style whole-dataset traversal.

### Failure and invalidation

- Cache failure MUST degrade to the authoritative path where capacity and safety permit. The fallback must be protected from a thundering herd by bounded concurrency, request coalescing, or another reviewed control.
- Authorization, account state, booking ownership, financial outcome, provider verification, and safety decisions MUST NOT trust a potentially stale cache without authoritative validation.
- Writes commit to PostgreSQL first. Cache invalidation/update occurs after the authoritative change and is safe to repeat.
- Cache entries SHOULD tolerate early eviction and missing values at any time.
- A stale-value strategy is allowed only when the endpoint documents maximum staleness and the data is safe to serve stale.
- Redis outage behavior, memory limits, eviction policy, connection timeouts, and circuit-breaking must be tested before production.
- Redis persistence is not a substitute for an authoritative store. If a future use cannot tolerate total Redis data loss, it requires a new ADR or an update that identifies recovery guarantees.

### Coordination safety

- A distributed lock alone MUST NOT be the only guard for money, booking assignment, verification, or destructive operations.
- Lock ownership uses unique opaque values and compare-and-delete release semantics.
- Locks require bounded lease times, acquisition deadlines, and cancellation handling.
- Long-running ownership requires fencing tokens or an equivalent monotonic authority checked by the protected resource.
- Network partitions, paused clients, expired leases, failover, and duplicate execution must be covered by tests for each coordination use.

## Object-storage conventions

### Object classes

Initial expected classes are:

| Class | Examples | Default access |
| --- | --- | --- |
| Provider verification | Identity or qualification documents | Authorized provider workflow and assigned reviewers only |
| Customer issue media | Images or audio supplied for a service request or AI assistance | Authorized booking/customer workflow and approved processing services only |
| Complaint evidence | Images, documents, or other case evidence | Assigned trust/safety workflow only |
| Generated artifacts | Invoices or exports | Authorized owner and approved operations only |

Each class requires approved type/size limits, retention, deletion, legal-hold behavior, malware controls, and access roles before implementation. Adding a materially different class requires architecture/privacy review.

### Object identity and metadata

- Buckets/containers are private and separated by environment. Production data MUST NOT be copied into lower environments by default.
- Object keys use random opaque identifiers and MUST NOT contain names, phone numbers, booking descriptions, original filenames, addresses, document types that reveal identity, or other sensitive data.
- PostgreSQL stores the authoritative metadata: object ID, class, owner/domain reference, storage locator, expected size, media type, integrity digest, scan state, lifecycle state, created time, retention category, and deletion state.
- Domain records reference the metadata ID, not a provider URL.
- Original filenames, when product-approved, are treated as untrusted display metadata, length-limited, encoded for output, and never used as a filesystem/object key.
- The service validates declared type, detected content, size, count, and digest. Client-provided media type and extension are not trusted.

### Upload and download flow

1. An authenticated caller requests upload authorization for an approved object class and domain owner.
2. The backend authorizes the action, creates a pending metadata record, and returns a narrowly scoped short-lived upload mechanism.
3. The client uploads directly or through a bounded service path according to the selected provider adapter.
4. The backend verifies expected size/digest and moves the object through quarantine and malware/content validation.
5. Only a successfully validated object becomes available to authorized workflows.

- Signed URLs or equivalent delegated access MUST be short-lived, single-purpose where supported, method/content constrained, and issued only after backend authorization.
- Possession of a storage URL MUST NOT be the platform's long-term authorization model.
- Downloads SHOULD use short-lived authorization and safe content headers; active content must not execute in a trusted application origin.
- Public ACLs and anonymous bucket/container access are prohibited.
- Listing access is restricted to service workflows; clients receive authorized object references, not bucket listings.

### Encryption, lifecycle, and deletion

- Encrypt objects in transit and at rest using provider-supported controls and approved key management.
- Key access follows least privilege and is separated by environment; secrets and key material never enter Git.
- Versioning or an equivalent recovery control SHOULD protect approved classes from accidental overwrite/deletion, but lifecycle rules must prevent indefinite sensitive-data retention.
- Retention policies operate from authoritative metadata and approved legal/privacy rules, not from ad hoc object names.
- Deletion is a workflow: revoke access, mark intent/state, delete versions/replicas under policy, retain only required audit evidence, and verify completion.
- Legal holds override ordinary deletion only under approved policy and must be auditable.
- Provider replication, residency, and immutable retention features require legal, privacy, cost, and recovery review before production.

## Data classification and handling

| Classification | Examples | Baseline handling |
| --- | --- | --- |
| Public | Published service-category names or approved public help content | Integrity controls; explicit publication only |
| Internal | Non-sensitive configuration metadata and operational references | Authenticated service/admin access; no public default |
| Confidential | User profiles, bookings, support records, provider skills/areas | Least privilege, encryption, purpose and retention limits, audited administrative access |
| Restricted | Authentication material, KYC, precise location, payment-provider records, complaints/evidence, emergency data, private media | Strongest access isolation, field/object minimization, explicit audit, short justified retention, focused security/privacy review |

- Classification follows the most sensitive field in a record or object unless safe physical/logical separation is proven.
- Logs, metrics, traces, caches, backups, exports, test fixtures, and analytics inherit the handling requirements of the data they contain.
- Sensitive values MUST NOT be copied into identifiers, URLs, Redis keys, exception text, or unredacted telemetry.
- Production data is not approved for local development, automated tests, demos, or AI evaluation datasets.

## Retention and deletion

- Every domain table and object class MUST have an owner and one approved retention category before production.
- A retention category defines purpose, trigger, duration, deletion/anonymization method, legal-hold behavior, backup implications, and verification evidence.
- Exact durations remain `TBD` pending OD-006, OD-009, OD-010, OD-013, OD-016, and OD-020. Implementations MUST NOT silently choose indefinite retention.
- Cache TTL is not a durable deletion mechanism. Database, object versions, replicas, exports, indexes, search stores, analytics copies, and backups require lifecycle coverage.
- Account deletion must preserve only records legally or operationally required and must sever or anonymize relationships where approved.
- Audit records preserve accountability but MUST minimize copied business payloads and follow their own approved retention.
- Backup expiration may delay physical erasure only under an approved, documented policy that prevents restored data from silently returning to active use.

## Schema migration conventions

### Ownership and source

- Migrations are source artifacts owned by the backend domain that owns the affected data.
- Generated migrations are reviewed as code; generated status does not exempt them from safety review.
- Applied migration identifiers and checksums must be recorded. An applied migration file MUST NOT be edited; create a new migration.
- Migration order is deterministic, and every environment applies the same reviewed sequence.
- Runtime application startup MUST NOT automatically apply production migrations.

### Expand, migrate, contract

Breaking data changes use staged compatibility:

1. **Expand:** add compatible nullable fields/tables/indexes or dual-read capability.
2. **Migrate:** backfill in bounded, restartable, observable batches and verify invariants.
3. **Switch:** move reads/writes after compatibility and reconciliation checks.
4. **Contract:** remove old data only after all supported application versions and rollback windows no longer depend on it.

- Large indexes/constraints use the database's low-lock validation/build mechanisms where available and tested.
- Backfills MUST have rate controls, checkpoints, idempotency, failure recovery, and production-impact monitoring.
- A migration that changes or deletes personal/financial/audit data requires retention and rollback review.

### Rollback and destructive change

- Every migration change includes a rollback or forward-recovery plan. A down migration is not automatically safe once new writes exist.
- Destructive operations—drop, truncate, narrowing conversion, irreversible rewrite, mass delete—require explicit approval, exact target verification, tested backup/restore evidence, and a staged rollout.
- Prefer a forward fix when rollback would discard valid new data.
- Deployment rollback and schema rollback are separate decisions; application versions must declare compatible schema ranges.
- Migration completion requires structural validation, row/invariant reconciliation, application smoke tests, and observability review.

## Backup, restore, and continuity

### PostgreSQL

- Production requires encrypted automated backups plus point-in-time recovery capability or an approved equivalent.
- Recovery point objective (RPO), recovery time objective (RTO), backup frequency, retention, and geographic placement remain `TBD` pending OD-017/OD-018.
- Backups must include required roles/schema/configuration metadata without embedding unmanaged credentials.
- Restore drills run into an isolated environment, validate integrity and application invariants, record achieved RPO/RTO, and ensure restored sensitive data retains production-equivalent access controls.
- Backup existence is not evidence of recoverability; successful tested restoration is required.

### Redis

- Cache and presence state are rebuilt rather than restored.
- Configuration, infrastructure definitions, and key schemas are version-controlled; data is disposable under the approved uses.
- If a future coordination use needs recovery, its persistence and failover mode require focused validation and potentially a new ADR.

### Object storage

- Required classes use approved versioning/replication or backup controls consistent with retention, residency, and cost policy.
- Restore drills verify metadata-to-object reconciliation, integrity digests, authorization, lifecycle state, and deletion/legal-hold behavior.
- Orphaned metadata and orphaned objects are detected by bounded reconciliation jobs that do not expose object listings to clients.

## Environment and test isolation

- Local, development, staging, and production use separate databases, Redis namespaces/instances, object containers, credentials, and encryption boundaries.
- Tests use isolated ephemeral data and deterministic fixtures containing no production personal data.
- Parallel tests use unique database/schema, key namespace, and object prefix/container boundaries.
- Integration tests cover transaction races, constraint violations, migration up/forward recovery, cache loss, stale cache, eviction, Redis unavailability, upload validation, quarantine, unauthorized object access, deletion, and restore reconciliation.
- Seed data is clearly synthetic and does not resemble real credentials or customer records.

## Observability and audit

- Measure connection pool saturation, query latency, lock waits, deadlocks, storage growth, backup age, restore results, Redis memory/eviction/hit rate, object errors, scan backlog, and reconciliation drift.
- Telemetry uses opaque correlation/reference IDs and MUST NOT contain SQL parameters, Redis values/keys with business identifiers, signed URLs, object contents, or sensitive metadata.
- Access to restricted objects and privileged data operations must emit audit events with actor, purpose/action, target reference, time, and outcome.
- Alert thresholds, owners, and runbooks are required before production and derive from approved SLO/RPO/RTO and budget targets.

## Provider and version selection gates

The decisions above select capability types, not hosted vendors. Before implementation or production use:

- Pin supported PostgreSQL and Redis major versions after checking runtime/ORM compatibility, security support, upgrade path, license, and managed-service availability.
- Select hosted/self-managed providers through ADRs that cover region/residency, encryption/key control, networking, backups, failover, observability, support, portability, and total cost.
- Select the object-storage adapter/provider without leaking vendor SDK types into domain code.
- Review dependency source, maintenance, and license before installation.
- Put credentials in the approved secret manager or local untracked environment only.

## Implementation review checklist

- [ ] Store ownership and source-of-truth rules are explicit.
- [ ] Constraints and transaction boundaries protect critical invariants.
- [ ] Migration, backfill, compatibility, rollback, and verification plans are reviewed.
- [ ] Redis data is reconstructable and each key has a safe namespace, schema, bound, and TTL.
- [ ] Object classes, metadata, validation/quarantine, access, encryption, retention, and deletion are defined.
- [ ] Data classification, minimization, audit, retention, legal hold, and environment isolation are approved.
- [ ] Backup and restore procedures meet tested RPO/RTO requirements.
- [ ] Failure modes, reconciliation, monitoring, cost, and operational ownership are documented.
- [ ] No real credentials, production data, or public storage access is introduced.

## Primary references

- [PostgreSQL transactions](https://www.postgresql.org/docs/current/tutorial-transactions.html)
- [PostgreSQL constraints](https://www.postgresql.org/docs/current/ddl-constraints.html)
- [PostgreSQL explicit locking](https://www.postgresql.org/docs/current/explicit-locking.html)
- [Redis eviction](https://redis.io/docs/latest/develop/reference/eviction/)
- [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
- [Amazon S3 data consistency](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html#ConsistencyModel)
- [Amazon S3 data protection and encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/DataDurability.html)

These references support capability analysis; they do not select a hosted provider or replace provider-specific security and operations review.
