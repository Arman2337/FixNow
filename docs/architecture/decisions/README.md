# Architecture Decision Records

Architecture Decision Records (ADRs) capture choices that are expensive to reverse or affect multiple components.

## Naming

Use four digits and a short kebab-case title:

```text
0001-select-primary-database.md
```

## Lifecycle

Use one status: `Proposed`, `Accepted`, `Deprecated`, or `Superseded by ADR-NNNN`. Never rewrite an accepted decision to hide history; create a new ADR and link both records.

Start with [`0000-template.md`](0000-template.md).

## Records

- [ADR-0001: Adopt a versioned JSON HTTP API](0001-adopt-versioned-json-http-api.md) — Accepted
- [ADR-0002: Use PostgreSQL as the transactional system of record](0002-use-postgresql-system-of-record.md) — Accepted
- [ADR-0003: Use Redis for ephemeral cache and coordination](0003-use-redis-ephemeral-cache.md) — Accepted
- [ADR-0004: Store binary artifacts in private object storage](0004-use-private-object-storage.md) — Accepted
- [ADR-0005: Use centralized hybrid authorization](0005-use-centralized-hybrid-authorization.md) — Accepted
- [ADR-0006: Use transactional outbox events and WebSocket projections](0006-use-outbox-events-and-websocket-projections.md) — Accepted
