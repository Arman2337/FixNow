# ADR-0003: Use Redis for ephemeral cache and coordination

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering

## Context

FixNow expects read caching, rate limits, short-lived provider presence, freshness markers, and some bounded coordination needs. These workloads benefit from low-latency atomic operations and expiry. They do not justify weakening PostgreSQL's role as the authoritative source of truth.

Cache eviction, restart, failover, expiration, or network partition can remove or stale data. Booking assignment, payments, verification, identity, audit, and safety workflows therefore cannot depend on Redis as their only durable or correctness boundary.

## Decision

Use Redis for explicitly approved, ephemeral, reconstructable workloads.

- Allowed uses include cache-aside data, bounded counters/rate limits, short-lived presence, and carefully reviewed coordination protected by authoritative invariants.
- Redis is not the source of truth for durable domain state, consequential idempotency outcomes, financial records, audit history, or provider verification.
- Every ordinary key is versioned, bounded, non-sensitive in name/content, and has an intentional TTL.
- Code must tolerate missing, evicted, expired, stale, or unavailable cache data.
- Distributed locks are advisory coordination only; consequential workflows also require database invariants and fencing where long-running ownership exists.
- Queues, durable event streams, background scheduling, and real-time transport are not selected by this ADR.
- The exact Redis major version, license, deployment/managed provider, topology, persistence mode, client library, eviction policy, and memory limits require implementation and provider review.

## Consequences

### Positive

- Redis supports low-latency expiry, counters, and atomic primitives suited to cache, presence, and abuse-control workloads.
- Explicitly disposable data reduces restore complexity and prevents a second system of record.
- A versioned namespace and TTL policy make invalidation, environment isolation, and schema evolution visible.
- Provider choice can remain deferred because domain code depends on a bounded cache/coordination interface.

### Costs and risks

- Cache invalidation, stampede control, memory bounds, hot keys, and eviction require design and monitoring.
- Stale cache can create privacy or authorization defects if code bypasses the authoritative source.
- Locks can fail under pauses, partitions, failover, or expired leases; misuse can duplicate effects.
- Redis licensing and managed-service compatibility can change, so version/provider selection requires current legal and dependency review.
- Falling back to PostgreSQL during an outage can overload the authoritative store if concurrency is not bounded.

### Privacy and operations

- Keys and values must be minimized, non-identifying where possible, encrypted in transit, access-restricted, and short-lived. Redis must not become an ungoverned copy of profiles, precise locations, tokens, complaints, or payment records.
- TTL and eviction do not prove privacy deletion or retention compliance across persistence files, replicas, logs, or backups; the selected deployment must match the approved ephemeral role and retention policy.
- Production ownership includes memory/eviction policy, connection and command controls, patch/license review, failover testing, outage fallback, capacity protection, monitoring, and cost limits.

## Alternatives considered

### No shared cache

Starting without Redis would reduce infrastructure, and implementations should still avoid caching until measurement shows need. However, planned presence and rate-limit workloads require shared ephemeral atomic state across backend instances. This ADR approves the capability while requiring each use to justify itself.

### PostgreSQL for every ephemeral workload

PostgreSQL can support counters, locks, and short-lived data, but high-churn presence and cache workloads may add avoidable write amplification and contention. PostgreSQL remains the fallback/authority where correctness requires it.

### Application-memory cache only

Per-process memory is useful for safe bounded local optimizations but cannot coordinate limits or presence across instances and becomes inconsistent during scaling/restart. It may complement but not replace required shared ephemeral state.

### Redis as durable queue or primary database

Those uses introduce durability, replay, failover, backup, ordering, and recovery requirements not established by FN-012. Event transport is deferred to FN-015, and PostgreSQL remains authoritative.

## Validation

- Test cache hit/miss/stale behavior, early eviction, total data loss, Redis outage, timeout, failover, and fallback load.
- Test rate-limit atomicity, expiry, scope, and abuse boundaries.
- Test every coordination use under duplicate execution, expired lease, delayed client, partition/failure, and fencing conditions.
- Monitor memory, fragmentation, eviction, hot keys, hit rate, latency, connections, errors, and authoritative fallback load.
- Reconsider a use if it cannot safely tolerate Redis data loss or if operational/license constraints make the selected version/provider unsuitable.
