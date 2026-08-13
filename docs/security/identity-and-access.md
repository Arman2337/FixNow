# Identity, roles, and permissions

## Status and scope

This document defines FixNow's identity boundaries, role model, permission evaluation, privileged-access controls, and lifecycle expectations. It is normative architecture, not evidence that authentication or authorization is implemented.

The detailed baseline is in the [permission matrix](permission-matrix.md). [ADR-0005](../architecture/decisions/0005-use-centralized-hybrid-authorization.md) records the decision to centralize authorization in the backend using roles plus resource/context policy.

This task does not select an identity provider, credential type, OTP vendor, token format, federation protocol, or recovery method. Those choices require the product decisions identified by OD-005 and a separate ADR before implementation.

## Backend enforcement baseline

FN-027 implements the first trusted-backend enforcement boundary under this model. A global NestJS authorization guard denies routes unless they are explicitly marked public or declare an exact registered permission. Protected requests validate the access-token issuer, audience, expiry, active database session, authoritative account status, and current non-expired database role assignments; role and account-status claims in the token are not authorization authority.

Resource policy receives ownership, assignment, target, and independent-approval facts only after the application loads them from authoritative domain state. Missing policy or context, inactive accounts, revoked sessions, unknown permissions, cross-role access, ownership mismatch, self-grant, and absent independent approval fail closed. Decisions emit minimal authorization classifications to the authentication audit store without tokens, email addresses, resource identifiers, or request payloads.

Existing registration, authentication, OTP, token renewal/logout, root, and health routes are explicitly public because they enforce their own credential, refresh-token, throttling, or operational boundary. Future backend routes are denied until their owning task assigns an exact permission and, where applicable, supplies authoritative resource context.

## Security principles

1. **Deny by default.** A request is denied unless an explicit policy permits the authenticated principal to perform the action on the resource in its current context.
2. **Authorize every request.** Authentication, a prior check, possession of an identifier, or UI visibility never substitutes for authorization at the trusted backend boundary.
3. **Least privilege.** Human and service principals receive only permissions needed for a defined purpose and duration.
4. **Resource-aware policy.** A role grants candidate permissions; ownership, assignment, relationship, state, purpose, assurance, and other attributes determine whether a particular request is allowed.
5. **Server authority.** Client, identity-provider, AI, webhook, cache, and external-service claims are untrusted until validated and mapped to authoritative internal records.
6. **Separation of duties.** Provider review, financial operations, trust enforcement, role administration, and security audit are separate capabilities.
7. **Safe failure.** Missing policy, unavailable authorization dependencies, stale identity state, or indeterminate context results in denial for protected actions.
8. **Auditable privilege.** Sensitive reads and consequential writes have reason, actor, target, time, outcome, and correlation evidence appropriate to the data class.

## Identity concepts

| Concept | Meaning |
| --- | --- |
| Principal | An authenticated or anonymous actor evaluated by policy: human account, service identity, or tightly controlled emergency-access identity. |
| Human account | The internal identity record for one person, with status, verified attributes, sessions, and role assignments. It is not a provider business/profile record. |
| Persona | The product context in which a human acts, such as customer, provider applicant, verified provider, or privileged staff. |
| Role | A reviewed bundle of candidate permissions. A role alone never establishes resource ownership or valid lifecycle state. |
| Permission | A stable, machine-readable ability to attempt one action on one resource type within an allowed scope. |
| Policy | The authoritative rule that combines permission with resource, relationship, state, purpose, assurance, and environmental conditions. |
| Service principal | A non-human workload identity with a narrow capability, environment, audience, and lifecycle. It is not a shared API key. |
| Session | A bounded authenticated context linked to a principal, assurance evidence, issue/expiry times, and revocation state. |
| Actor context | The explicitly selected persona/privileged role under which a request is made. It prevents hidden union of unrelated privileges. |

## Identity boundaries

### Internal identity authority

- PostgreSQL stores the authoritative application account ID, account state, provider association, role assignments, grants, revocations, and security/audit references.
- An external identity provider MAY prove authentication facts after a later ADR, but its subject, group, role, email, or phone claims MUST be validated and mapped to an internal identity.
- External provider groups/claims MUST NOT directly authorize FixNow domain actions.
- Domain records reference opaque internal IDs, not phone numbers, email addresses, provider subjects, access tokens, or device tokens.
- One person MUST NOT gain duplicate privileges through account linking. Link, merge, recovery, and duplicate-identity handling require explicit verified workflows and audit.

### Human personas

- A human MAY have customer and provider personas only under an approved account-linking/product policy; provider eligibility still depends on verification state.
- Privileged staff access SHOULD use a separate administrative identity/session from ordinary customer/provider activity to reduce confused-deputy and session-compromise risk.
- A request that enters a privileged context MUST name one active staff role/purpose. The backend MUST NOT silently union every role a person holds when separation matters.
- Switching to or elevating a privileged context requires fresh authorization evaluation and MAY require step-up authentication according to the high-risk action table.

### Service identities

- Every deployable workload/integration has its own service principal per environment and purpose.
- Service permissions are explicitly allowlisted by API/action and resource scope; service identities do not inherit human roles.
- Workload credentials are short-lived where the platform supports it, audience-bound, rotated, revocable, and stored only in an approved secret system.
- Background work carries the initiating actor/correlation reference separately when user attribution is required. It MUST NOT impersonate a user through an unrestricted token.
- External callbacks authenticate as a provider/integration boundary and still pass domain validation and idempotency checks.

## Baseline roles

Roles are additive candidate grants subject to policy. The detailed action mapping is in the [permission matrix](permission-matrix.md).

| Role | Purpose | Explicit boundary |
| --- | --- | --- |
| Anonymous | Registration, authentication entry, approved public/reference content | No personal, booking, provider-private, financial, or administrative data |
| Customer | Manage own customer profile and participate in own eligible requests/bookings | No access to another customer or provider-private data |
| Provider applicant | Manage own onboarding profile, skills, service areas, and verification submissions | Cannot receive normal jobs or approve verification |
| Verified provider | Manage own availability and assigned/eligible provider workflows | Verification state, assignment, booking state, and ownership are still enforced |
| Provider reviewer | Review assigned provider applications/documents and record decisions | No payment operations, role administration, or unrelated document browsing |
| Support agent | Provide bounded customer/provider/booking support using minimized views | No raw KYC, unrestricted location, payment execution, role grants, or security configuration |
| Trust and safety reviewer | Handle assigned complaints/evidence and approved enforcement workflows | No payment settlement, role administration, or unrelated bulk export |
| Finance operator | Reconcile transactions and perform policy-allowed refunds/financial operations | No KYC review, trust enforcement, or general user impersonation |
| Service catalog manager | Maintain service categories and approved taxonomy policy | No user, booking intervention, payment, KYC, or role administration |
| Operations administrator | Perform explicitly approved account/provider/booking operational interventions | No role/security administration, direct database access, or unrestricted financial/KYC actions |
| Security administrator | Manage staff/service access, revoke sessions, review security audit, and operate access controls | No business-data access by default; cannot self-approve high-risk grants |
| Auditor | Read approved immutable audit evidence and control reports | No domain mutation, role grant, secret access, or unrestricted payload access |
| Service principal | Execute one documented machine capability | No human role inheritance or cross-environment access |
| Break-glass principal | Time-limited emergency access under the break-glass procedure | Disabled by default; never used for routine operations |

“Administrator” in product language is a collective term for one or more narrow staff roles above. It is not a wildcard role.

## Permission model

### Permission naming

Permissions use stable lowercase segments:

```text
{domain}.{resource}.{action}.{scope}
```

Examples:

```text
users.profile.read.self
providers.application.review.assigned
bookings.booking.update.assigned
payments.refund.create.authorized
access.role.grant.authorized
```

- `domain` identifies the policy owner.
- `resource` is singular and stable across transport/implementation names.
- `action` is a concrete verb such as `read`, `create`, `update`, `cancel`, `approve`, `refund`, `export`, or `grant`.
- `scope` expresses the maximum candidate relationship, such as `self`, `assigned`, `authorized`, or `service`.
- A broad scope does not bypass policy. For example, `authorized` still requires the actor's role, purpose, resource state, approval limit, and data classification to allow the action.
- Wildcard permissions are prohibited in application roles. Any infrastructure wildcard requires a separate least-privilege review outside this model.
- Permission meaning MUST NOT be changed in place. Add a new permission and migrate grants when semantics change.

### Policy inputs

The backend policy decision uses all relevant authoritative inputs:

- Principal ID/type and account/service status.
- Active actor context and current role assignments.
- Session assurance, authentication time, expiry, revocation, and step-up evidence.
- Requested permission/action and API audience/environment.
- Resource type, ID, owner, participants, assignment, data classification, and lifecycle state.
- Provider verification, category eligibility, availability, and service-area relationship where relevant.
- Booking/payment/complaint/emergency state and legal transition rules.
- Staff assignment, purpose/reason, approval limit, dual-control status, and support case where required.
- Policy version and safe environmental signals such as trusted workload identity; network location alone is not sufficient authorization.

Client-supplied role, ownership, provider status, booking status, price, refund limit, or staff assignment is never authoritative.

### Decision algorithm

For every protected action, the policy enforcement point MUST:

1. Authenticate and validate the principal/session for the endpoint audience and environment.
2. Resolve authoritative internal identity, status, active actor context, and candidate roles/permissions.
3. Load the minimum authoritative resource/policy attributes needed for the decision.
4. Apply explicit deny conditions first, including inactive/revoked identity, invalid context, forbidden state, or missing required assurance.
5. Require an exact candidate permission; no wildcard or inferred permission.
6. Evaluate ownership/assignment, lifecycle, purpose, data class, separation-of-duty, approval, and field-level disclosure rules.
7. Deny if data is missing, stale beyond approved bounds, policy evaluation errors, or a required dependency is unavailable.
8. Return only the authorized representation and emit required audit evidence.

Policy decisions MUST be deterministic for the same authoritative inputs and policy version. Denials use safe API error conventions and do not reveal protected resource existence.

## Resource and field-level rules

- Collection/list permission and single-resource read permission are separate; permission to read one known resource does not imply search/list capability.
- Read, create, update, delete, transition, export, and administrative intervention are separate actions.
- Ownership is established from authoritative relationships, not from a request body or URL alone.
- A participant in a booking sees only fields required for the current relationship/state. Precise location, contact details, payment metadata, complaint evidence, and internal notes need separate policy.
- Support/admin views use minimized projections. Raw records and unrestricted “view all” endpoints are prohibited.
- Field updates use allowlists per role and state; mass assignment from client objects is prohibited.
- Historical participation does not imply indefinite access to live location, private provider documents, complaint evidence, or another party's full profile.
- Export/bulk access is a separate high-risk permission with purpose, bounds, approval, watermarking/protection where appropriate, and audit.
- Cache may accelerate an authorization lookup only when staleness is safe and bounded. Consequential policy relies on authoritative state as defined by the [data architecture](../architecture/data-architecture.md).

## Account and role lifecycle

### Account states

The baseline state model is:

| State | Access behavior |
| --- | --- |
| Pending verification | Only approved verification, recovery, and support paths |
| Active | Normal policy evaluation applies |
| Restricted | Only explicitly allowed remediation/support paths; reason and scope are recorded |
| Suspended | Existing sessions revoked; no normal access; approved appeal/support paths only |
| Deactivated | User-initiated or administrative deactivation; sessions revoked; reactivation follows approved policy |
| Deletion pending | No new ordinary processing; legal/operational checks and deletion workflow apply |
| Deleted/anonymized | No authentication; retained records limited to approved legal/audit obligations |

- State names may be refined during FN-023, but semantics cannot be weakened without review.
- State transitions require explicit actors, reasons, legal transitions, timestamps, audit, session impact, and active-booking/provider-case handling.
- Restriction/suspension is not deletion; retention and appeal rules remain separate.

### Role assignment

- Customer/provider eligibility roles derive from authoritative account/provider lifecycle; staff roles use a controlled grant workflow.
- Every staff/service role grant records requester, approver where required, subject, role, scope, environment, purpose, start, expiry/review date, and outcome.
- High-risk roles cannot be self-approved. Requester, approver, and auditor separation follows the control matrix.
- Temporary access expires automatically. Permanent privileged access requires periodic recertification at a policy-approved interval (`TBD`).
- Transfers, role changes, offboarding, suspected compromise, and inactivity trigger prompt grant/session review and revocation.
- Removing a role invalidates affected sessions/caches within an approved maximum delay; high-risk revocation is immediate or fails closed.
- Role definitions and policies are version-controlled, code-reviewed, tested, and deployed through the normal change process. Production administrators MUST NOT invent ad hoc permissions.

## High-risk action controls

| Action | Minimum control |
| --- | --- |
| Read provider KYC or complaint evidence | Assigned narrow role, recorded purpose/case, field/object minimization, audit, no bulk download |
| Approve/reject provider | Provider reviewer, valid assigned application state, reason; reviewer cannot approve own/related application |
| Suspend/restrict account or provider | Authorized operations/trust role, enumerated reason, evidence/case reference, audit, appeal path; second approval where policy classifies impact as severe |
| Grant/revoke privileged role | Security administrator plus independent approval for high-risk roles; cannot self-grant; automatic expiry/review |
| Issue refund or financial adjustment | Finance permission, verified transaction state, amount/limit policy, idempotency, reason; second approval above `TBD` threshold |
| View precise live location | Active authorized booking/emergency relationship and allowed lifecycle state; purpose-limited access and audit where required |
| Export personal/financial/trust data | Separate export permission, documented purpose, bounded dataset, approval, encryption, expiry/deletion, and audit |
| Delete/anonymize account data | Verified request/authority, retention/legal-hold check, dual control for exceptional override, staged/audited deletion |
| Modify service category with active dependencies | Catalog permission, compatibility/impact review, audit; historical contracts remain interpretable |
| Access emergency request data | Assigned operational purpose, active case/state, restricted projection, enhanced audit and review |
| Break-glass access | Declared incident, strong step-up authentication, narrow time-bound grant, independent notification, full audit, immediate post-use review and revocation |

Numeric refund, export, session, recertification, and step-up thresholds remain `TBD` pending product/security policy. Implementations must not silently choose “unlimited.”

## Authentication and session requirements

FN-013 does not choose authentication mechanisms, but later choices MUST satisfy these authorization inputs:

- Credentials and recovery evidence are separate from profile/contact data and never logged.
- Authentication establishes an internal principal and assurance context, not domain permission.
- Privileged and high-risk actions support fresh/step-up authentication appropriate to approved risk.
- Sessions are audience/environment bound, short enough for risk, revocable, rotated where applicable, and protected against replay/theft.
- Password/OTP/federation/token policies follow the selected assurance and current vetted standards; custom cryptography is prohibited.
- Session lists, logout-all, compromise response, credential change, account-state change, and staff offboarding have explicit revocation behavior.
- Long-lived service credentials are avoided where workload identity or short-lived credentials are available.
- Authentication errors and recovery flows prevent account enumeration according to the [API error conventions](../architecture/error-response-conventions.md).

### Administrative web sessions

- Administrative sign-in uses a dedicated backend entry point and an admin-specific access-token audience; mobile-audience tokens are not accepted for administrative session checks.
- Only active identities with exactly one current staff role can establish an administrative session. Customer, provider, missing-role, expired-role, and ambiguous multi-role attempts receive the same safe authentication failure.
- The administrative web application stores access and rotating refresh tokens in HTTP-only, secure-in-production, strict same-site cookies. Browser JavaScript cannot read them.
- Navigation visibility reflects the current server-authorized staff role for orientation only. Every protected backend operation still performs authoritative permission evaluation.
- Expired access sessions may use the existing one-time rotating refresh flow. Failed refresh, unauthorized access, and explicit logout clear local session cookies; logout also revokes the backend refresh session when reachable.

### Administrative management projections

- User management exposes opaque account IDs, account status, current non-expired role codes, and timestamps only. It does not expose credentials, identity subjects, contact details, status reasons, or unrestricted raw records.
- Provider verification list/detail views expose the professional profile fields required for review while excluding precise base coordinates. Review history retains actor attribution, version, transition, reason, and timestamp.
- Provider documents are available only to the reviewer currently assigned to the application. Reads are audited, returned with private no-store caching, and never expose object-storage keys or hashes.
- Claim and decision operations reuse the authoritative provider verification state machine, assignment checks, self-review protection, required reasons, and optimistic version checks. UI state never bypasses these backend rules.

## Audit and observability

Audit-worthy events include:

- Authentication, recovery, MFA/assurance, session issuance/revocation, and suspicious failures at policy-approved granularity.
- Account linking/merge, state transitions, provider verification, role grants/revocations, permission/policy changes, and break-glass use.
- Restricted data reads, exports, KYC/evidence access, refunds, enforcement actions, deletion/legal hold, and high-risk denials.

Each audit event SHOULD include opaque actor and target references, actor context, action, purpose/reason or case reference where required, policy version, time, outcome, correlation ID, and approved client/service context. It MUST NOT include credentials, tokens, OTPs, raw KYC/evidence, precise location payloads, or full request/response bodies.

- Authorization-denial metrics use bounded classifications and must not create a side channel or high-cardinality personal-data store.
- Security alerts require an owner and runbook before production.
- Audit access is itself permissioned and audited. Auditors cannot mutate the evidence they review.
- Audit retention, integrity, and legal use are finalized by FN-014 and relevant product/legal decisions.

## Testing requirements

Every protected capability MUST include tests for:

- Unauthenticated, expired/revoked session, inactive account/service, and wrong audience/environment.
- Every allowed role/resource relationship plus every adjacent disallowed role.
- Same-role cross-user/cross-provider ownership attempts and identifier tampering.
- Invalid resource/lifecycle state, stale assignment, provider verification changes, and concurrent state changes.
- Missing policy/attributes, authorization dependency error, and fail-closed behavior.
- Field-level redaction and collection/list versus individual-resource access.
- Privilege grant, expiry, recertification, revocation propagation, separation of duties, and self-approval prevention.
- Step-up, dual control, reason/case requirements, amount limits, exports, restricted-data access, and break-glass procedure where applicable.
- Safe `401`/`403`/existence-protected `404` responses and audit evidence without sensitive data.

The complete matrix-based security suite is owned by FN-066 after implementation tasks exist.

## Open decisions and implementation gates

The following remain unresolved and MUST NOT be inferred from this model:

- Identity/OTP/federation provider and protocol.
- Primary identifiers, required verification attributes, MFA methods, and recovery proof.
- Whether customer and provider personas share one account in the launch product.
- Exact admin staffing model, role-assignment approvers, recertification interval, and support-case tooling.
- Step-up freshness, session duration, refund/export dual-control thresholds, and break-glass custodians.
- Account suspension, deletion, active-booking, legal hold, and appeal policies.
- Launch jurisdiction-specific identity, KYC, labor, privacy, financial, and emergency requirements.

FN-023 and later implementation tasks may refine entities and mechanics but MUST preserve deny-by-default, backend authority, separation of duties, resource/context policy, and audit boundaries unless a superseding ADR is accepted.

## Primary references

- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [NIST SP 800-207: Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final)
- [NIST SP 800-63B: Authentication and authenticator management](https://pages.nist.gov/800-63-4/sp800-63b.html)

These sources guide control design; the approved FixNow policy and applicable law remain authoritative for this project.
