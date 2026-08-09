# ADR-0004: Store binary artifacts in private object storage

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering

## Context

FixNow plans provider verification documents, customer issue images/audio, complaint evidence, invoices, and exports. These artifacts may be large, sensitive, and subject to content validation, retention, legal hold, deletion, and restricted download. Storing them directly in ordinary PostgreSQL rows would increase database backup, replication, migration, and query costs and would couple binary delivery to the transactional database.

The cloud provider, residency, exact artifact classes, retention periods, and production scale remain undecided. The architecture needs a secure storage boundary without exposing a vendor SDK or public bucket as a domain contract.

## Decision

Use private object storage for approved binary artifacts and keep authoritative metadata and access relationships in PostgreSQL.

- Buckets/containers are private, encrypted, environment-isolated, and inaccessible anonymously.
- Object keys are random opaque values without personal data, business data, or original filenames.
- PostgreSQL stores the metadata ID, class, owner/reference, storage locator, expected size/type/digest, scan state, lifecycle/retention state, and deletion state.
- Uploads use backend authorization and narrowly scoped short-lived delegated access or a bounded service path.
- New objects remain unavailable in quarantine until type, size, integrity, and required malware/content checks succeed.
- Downloads require current backend authorization and short-lived access with safe content headers.
- Versioning/replication, lifecycle, deletion, legal hold, reconciliation, and restore behavior follow approved data-class policy.
- The exact cloud/provider, region, API adapter, encryption-key service, malware scanner, CDN, and residency topology remain separate reviewed decisions.

## Consequences

### Positive

- Binary scale and delivery are separated from transactional query, backup, and migration workloads.
- Private objects plus backend-controlled metadata preserve authorization and lifecycle ownership.
- Direct delegated transfer can avoid routing large payloads through application memory while keeping authorization short-lived.
- A storage adapter and opaque metadata IDs limit vendor types in domain code.

### Costs and risks

- Database metadata and object state can diverge, requiring idempotent workflows and reconciliation.
- Signed/delegated URLs are bearer capabilities during their lifetime and require narrow scope and expiry.
- Upload validation, quarantine, malware scanning, safe serving, and deletion across versions/replicas add operational complexity.
- Versioning and replication can conflict with privacy deletion or create unexpected cost if lifecycle rules are wrong.
- Provider selection must account for residency, consistency, encryption, key control, support, egress cost, and portability.

### Privacy and operations

- KYC, complaint evidence, precise-location-related media, invoices, and exports can be restricted personal data. Access, purpose, retention, legal hold, residency, download audit, and verified deletion must be defined per object class.
- Short-lived delegated URLs reduce application transfer load but remain bearer capabilities; URL leakage, logs, browser history, referrers, and caching require preventive controls.
- Production ownership includes public-access prevention, encryption/key operation, scanning capacity, lifecycle/version cost, orphan reconciliation, restore drills, provider incidents, and deletion verification.

## Alternatives considered

### Store binaries in PostgreSQL

This offers transactional coupling with metadata but increases database size, backup/restore duration, replication load, and application delivery pressure. It remains acceptable only for small bounded values where a specific contract and measurement justify it.

### Store files on application-instance disks

Instance filesystems are difficult to share, scale, back up, restore, and preserve during replacement. They also risk path traversal and inconsistent state. Local disk may be used only for isolated temporary processing with bounded cleanup, never as durable production storage.

### Public object storage with hard-to-guess URLs

Unpredictable URLs are not authorization. Public access would expose sensitive KYC, location-related media, complaints, invoices, or exports and is prohibited.

### Select a cloud-specific storage service now

No cloud, region, residency, or cost decision is approved. The capability and security model can be defined now while provider selection remains a later ADR.

## Validation

- Test authorization, delegated-access scope/expiry, type/size/integrity validation, quarantine, malware/content rejection, and safe download headers.
- Test metadata/object reconciliation, duplicate callbacks, interrupted uploads, orphan cleanup, version-aware deletion, legal hold, and restore.
- Verify encryption, public-access prevention, least-privilege roles, environment isolation, audit events, and secret handling before production.
- Reconsider if artifact size/volume, latency, residency, transactional coupling, provider consistency, or cost cannot meet approved requirements.
