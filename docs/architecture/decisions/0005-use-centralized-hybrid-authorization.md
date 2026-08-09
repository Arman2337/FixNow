# ADR-0005: Use centralized hybrid authorization

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering and security

## Context

FixNow has customer, provider-applicant, verified-provider, staff, auditor, and service actors. Access depends not only on a named role, but also on resource ownership, provider verification, booking assignment and state, complaint assignment, data classification, purpose, session assurance, approval limits, and separation of duties.

Pure role checks would either create broad roles or scatter special cases across controllers and clients. Pure attribute policy without stable role bundles would be difficult to review and administer. Client-side or identity-provider group enforcement cannot protect backend resources.

## Decision

Use a centralized backend authorization model that combines role-based candidate permissions with resource, relationship, lifecycle, purpose, assurance, and environmental policy.

- Deny by default and authorize every protected request at the trusted backend boundary.
- Roles grant exact candidate permissions; wildcard application permissions are prohibited.
- Authoritative internal identity and domain state determine ownership, assignment, eligibility, and lifecycle.
- Identity-provider claims authenticate/map a principal but do not directly grant domain authorization.
- Policy evaluation fails closed when required identity, resource, policy, or assurance data is unavailable or invalid.
- Administrative access uses narrow roles and explicit actor context with separation of duties, time bounds, step-up/dual controls, and audit for high-risk actions.
- Mobile/admin UI checks are usability only and never authorization authority.
- The normative model and baseline matrix are [`../../security/identity-and-access.md`](../../security/identity-and-access.md) and [`../../security/permission-matrix.md`](../../security/permission-matrix.md).

This decision does not select an authentication/identity provider, credential method, token/session implementation, policy library, or hosted authorization service.

## Consequences

### Positive

- Policy reflects real ownership and lifecycle boundaries without granting broad administrator access.
- One reviewed model can drive endpoint checks, field projections, audit, and matrix-based tests.
- Identity-provider and client changes cannot silently redefine domain permissions.
- Narrow staff roles and separation of duties reduce privilege escalation and insider-risk blast radius.

### Costs and risks

- Policy inputs and resource loading add implementation and test complexity.
- Inconsistent policy-enforcement points or hidden direct data paths could bypass the centralized model.
- Caching authorization data risks stale privilege; revocation and high-risk checks need authoritative freshness.
- A single poorly designed authorization module can become a critical failure/security boundary and needs focused review and observability.
- Role/permission growth requires governance to avoid duplicate or contradictory semantics.

### Privacy and operations

- Authorization evaluation and audit process sensitive identity, relationship, KYC, location, payment, complaint, and emergency metadata. Inputs, logs, denial metrics, and audit payloads must be minimized and retention-controlled.
- Operational ownership includes policy versioning, review/deployment, role recertification, revocation propagation, alert/runbook coverage, break-glass custody, and evidence integrity.
- A policy outage denies protected actions by default; availability design must provide safe recovery without bypass modes.

## Alternatives considered

### Pure RBAC

Roles are useful administration bundles but cannot safely express “own booking,” “assigned complaint,” “verified provider in eligible category,” “refund below approval limit,” or lifecycle-specific location access without role explosion or scattered code.

### Pure ABAC or policy language from the start

Attribute policy can express detailed conditions but, before a toolchain and operational owner exist, would risk opaque policy, hard-to-review grants, and premature dependency selection. Stable roles plus explicit domain policy give a reviewable baseline; a future policy engine requires an ADR.

### Client-side authorization

Hiding controls improves usability but clients are untrusted and can call APIs directly. This cannot enforce security.

### Identity-provider groups as application roles

External groups simplify provisioning but couple domain authorization to provider configuration and cannot reliably express ownership/lifecycle. Provider claims are mapped to internal identities and controlled grants instead.

### One broad administrator role

A universal admin role violates least privilege and separation of duties across KYC, finance, trust, access administration, and auditing. Narrow roles are required.

## Validation

- Derive allow/deny tests from the permission matrix for every protected endpoint and field projection.
- Test cross-user/provider access, identifier tampering, invalid state, stale/revoked grants, policy/dependency failure, role conflict, self-approval, and high-risk controls.
- Verify every route and non-HTTP entry point has a policy-enforcement boundary and no client/provider claim bypasses internal mapping.
- Audit role grants, restricted reads, consequential actions, break-glass use, and policy changes without secrets or unnecessary sensitive data.
- Reconsider if measured complexity, availability, multi-tenant needs, external partnership, or policy scale requires a dedicated policy engine or different administrative model.
