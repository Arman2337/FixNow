# ADR-0002: Use PostgreSQL as the transactional system of record

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering

## Context

FixNow's planned identity, provider verification, booking lifecycle, payment records, complaints, authorization relationships, and audit references are relational and transaction-heavy. Critical operations include concurrent provider acceptance, state transitions, idempotent financial callbacks, uniqueness, ownership, and durable history. These require strong constraints and atomic transactions.

The product also expects location data, variable provider/service attributes, and evolving workflows, but current requirements do not justify multiple authoritative databases. A single primary transactional model reduces distributed consistency, recovery, access-control, migration, and operational complexity during the foundation phase.

## Decision

Use PostgreSQL as FixNow's authoritative transactional database.

- Authoritative domain records, relationships, lifecycle state, durable idempotency outcomes, object metadata, and audit references reside in PostgreSQL.
- Domain modules own their tables and access boundaries; application clients never connect directly.
- Structural invariants use explicit primary, foreign-key, unique, nullability, and check constraints where practical.
- Critical workflows use transactions and concurrency controls proven by integration tests.
- Schema changes follow the expand–migrate–switch–contract conventions in [`../data-architecture.md`](../data-architecture.md).
- Production requires encrypted backup and point-in-time recovery capability with tested restore procedures.
- The exact PostgreSQL major version, hosting model/provider, ORM/query library, identifier representation, geospatial extension, connection pooler, and analytics architecture remain implementation/provider decisions subject to compatibility and security review.

## Consequences

### Positive

- One transactional authority can enforce booking, identity, payment, verification, and ownership invariants atomically.
- Mature constraints, indexes, isolation, locking, JSON support, and extensibility cover current relational requirements without a second authoritative store.
- PostgreSQL has broad tooling and managed/self-managed deployment options, reducing vendor lock-in at the logical model.
- Backup, migration, audit, and access-control practices can center on one durable system.

### Costs and risks

- Schema and query governance is required to prevent a monolithic shared-table model.
- Long transactions, poor indexes, unsafe migrations, or unbounded queries can create contention and outages.
- Horizontal scaling and multi-region writes are not automatic; requirements exceeding a primary-region relational design would require reconsideration.
- JSON or extensions can become escape hatches that weaken relational contracts if adopted without review.
- Operational correctness depends on tested backups/restores, version upgrades, connection management, and least-privilege roles.

### Privacy and operations

- Centralizing identity, booking, financial, location-related, and trust metadata concentrates privacy impact. Table/column access, administrative access, exports, replicas, backups, and lower environments require least privilege and data-class handling.
- Retention, deletion, legal hold, residency, and restored-data behavior must be defined per domain; a database backup must not silently return deleted data to active use.
- Production ownership includes supported-version upgrades, capacity, pool and lock monitoring, encrypted backup, restore drills, incident response, and measured recovery objectives.

## Alternatives considered

### Document database as the primary store

Flexible documents fit some profiles and variable service attributes, but the core workflows depend on cross-record constraints, atomic transitions, relationships, and reconciliation. Introducing a document database would shift those guarantees into application code and add operational complexity without a demonstrated requirement.

### Multiple databases per domain from the start

Physical isolation can improve independent scaling and ownership, but it introduces distributed transactions, cross-store reporting, deployment, recovery, and consistency problems before traffic or team boundaries justify them. Logical module ownership inside PostgreSQL is the initial approach; future extraction requires an ADR and migration plan.

### Cloud-vendor proprietary relational database

A proprietary distributed database may offer managed scale or multi-region behavior, but launch scale, regions, availability targets, and budget are unresolved. Selecting one now would add cost and vendor coupling without evidence.

### Redis or object storage as authoritative state

Neither is appropriate for the relational, durable, transactional invariants required. Their bounded supporting roles are covered by ADR-0003 and ADR-0004.

## Validation

- Validate constraints, transactions, race handling, deadlock/serialization retry, migration compatibility, and parameterized queries through focused integration tests.
- Test backup restoration and point-in-time recovery against approved RPO/RTO before production.
- Review query plans, lock behavior, pool saturation, storage growth, and migration impact with representative synthetic data.
- Reconsider if measured requirements demand independently scaled domains, multi-region writes, incompatible data models, or availability that the selected PostgreSQL topology cannot meet safely and economically.
