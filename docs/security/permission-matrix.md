# Permission matrix

## How to read this matrix

This is the baseline authorization matrix for FixNow. It is intentionally explicit and deny-by-default.

| Symbol | Meaning |
| --- | --- |
| `A` | Candidate permission granted, still subject to resource/context policy |
| `C` | Conditional or exceptional permission requiring the noted control |
| `—` | No permission; deny by default |

Roles:

- `ANON` — Anonymous
- `CUS` — Customer
- `APP` — Provider applicant
- `PRO` — Verified provider
- `PRV` — Provider reviewer
- `SUP` — Support agent
- `T&S` — Trust and safety reviewer
- `FIN` — Finance operator
- `CAT` — Service catalog manager
- `OPS` — Operations administrator
- `SEC` — Security administrator
- `AUD` — Auditor

Service principals are excluded from the human-role columns because each receives a separate allowlist for one workload. Break-glass access is excluded because it is a time-bound emergency procedure, never an ordinary role grant.

An `A` is never global access. “Own,” “assigned,” “authorized,” current lifecycle state, data minimization, assurance, purpose, and other conditions in [Identity, roles, and permissions](identity-and-access.md) still apply.

## Public and account capabilities

| Capability | ANON | CUS | APP | PRO | PRV | SUP | T&S | FIN | CAT | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| View approved public service categories/help | A | A | A | A | A | A | A | A | A | A | A | A | Published, active fields only |
| Begin customer/provider registration | A | — | — | — | — | — | — | — | — | — | — | — | Abuse controls; no account enumeration |
| Authenticate/recover own account | A | A | A | A | A | A | A | A | A | A | A | A | Identity proof; safe generic responses |
| Read/update own basic profile | — | A | A | A | A | A | A | A | A | A | A | A | Self only; allowlisted fields; privileged staff use separate context |
| View own sessions and revoke own session(s) | — | A | A | A | A | A | A | A | A | A | A | A | Self only; fresh authentication for sensitive changes |
| Request own deactivation/deletion/export | — | A | A | A | A | A | A | A | A | A | A | A | Verified request, retention/legal-hold and active-work policy |

Staff roles retain personal self-service through their ordinary identity context, not through privileged domain permissions.

## Provider onboarding and verification

| Capability | CUS | APP | PRO | PRV | SUP | T&S | FIN | CAT | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Create/read/update own provider application | — | A | C | — | C | — | — | — | C | — | — | Applicant self; verified provider only for approved re-verification; support/ops through assigned case and restricted fields |
| Manage own skills/service area submissions | — | A | A | — | C | — | — | — | C | — | — | Self, valid category, editable state |
| Upload/read/delete own pending verification document | — | A | C | — | — | — | — | — | — | — | — | Authorized class, quarantine/retention rules; deletion only before policy lock |
| List assigned provider applications | — | — | — | A | — | — | — | — | C | — | C | Assignment/operational scope; auditor metadata only |
| Read assigned KYC/document | — | — | — | A | — | C | — | — | C | — | C | Recorded purpose, assigned case, minimum object, enhanced audit; support normally denied |
| Approve/reject/request resubmission | — | — | — | A | — | — | — | — | C | — | — | Valid transition, reason, no self/related review; operations exceptional only |
| Suspend/restrict provider eligibility | — | — | — | — | — | C | — | — | A | — | — | Approved reason/case, impact policy, appeal, dual approval where severe |
| Read verification audit evidence | — | C | C | A | C | C | — | — | A | C | A | Applicant/provider sees approved own status/reasons only; others minimized by role/purpose |

## Customer requests and bookings

| Capability | CUS | APP | PRO | PRV | SUP | T&S | FIN | CAT | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Create service request | A | — | — | — | — | — | — | — | — | — | — | Customer self, valid category/location/consent, idempotency |
| Read own/assigned booking | A | — | A | — | C | C | C | — | C | — | C | Customer participant or assigned provider; staff minimized to case/purpose |
| List own/assigned booking history | A | — | A | — | C | C | C | — | C | — | C | Paginated, minimized; staff bounded search and purpose |
| Receive/view eligible incoming request | — | — | A | — | — | — | — | — | — | — | — | Verified, available, category/service-area eligible; minimum customer detail |
| Accept booking | — | — | A | — | — | — | — | — | — | — | — | Eligible provider, atomic unassigned state |
| Progress assigned booking | C | — | A | — | C | — | — | — | C | — | — | Participant-specific legal transition; support/ops only documented intervention |
| Cancel own/assigned booking | A | — | A | — | C | — | — | — | C | — | — | Participant, cancellable state, disclosed policy/reason; staff through case |
| View precise active location | A | — | A | — | — | C | — | — | C | — | — | Active booking/emergency relationship, approved state/purpose, minimum precision |
| Modify completed booking history | — | — | — | — | — | — | — | — | — | — | — | Immutable history; corrections use auditable compensating workflow |
| Perform approved booking intervention | — | — | — | — | C | C | — | — | A | — | — | Assigned support/safety case, explicit action/reason, legal transition, audit |
| Read booking audit evidence | — | — | — | — | C | C | C | — | C | C | A | Minimum fields for assigned purpose; security metadata does not imply content access |

## Payments and earnings

| Capability | CUS | APP | PRO | PRV | SUP | T&S | FIN | CAT | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Create/verify own booking payment flow | A | — | — | — | — | — | — | — | — | — | — | Own eligible booking; backend verifies provider outcome |
| Read own transaction/invoice | A | — | A | — | C | — | C | — | C | — | C | Customer transaction or provider earning relationship; staff case/purpose |
| Read own provider earnings | — | — | A | — | C | — | C | — | C | — | C | Provider self; staff minimized and purpose-bound |
| Search/reconcile transactions | — | — | — | — | — | — | A | — | C | — | C | Finance scope; operations only approved incident; auditor read-only evidence |
| Create refund/adjustment | — | — | — | — | — | — | A | — | C | — | — | Finance role, amount limit, verified state, idempotency, reason, second approval above threshold |
| Approve high-value refund | — | — | — | — | — | — | C | — | C | — | — | Independent authorized approver; cannot approve own request |
| Alter settled transaction history | — | — | — | — | — | — | — | — | — | — | — | Prohibited; use immutable compensating records |
| Export financial data | — | — | — | — | — | — | C | — | — | — | C | Separate bounded export approval, encryption, expiry/deletion, audit |

## Ratings, complaints, and trust

| Capability | CUS | APP | PRO | PRV | SUP | T&S | FIN | CAT | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Submit rating/review | A | — | A | — | — | — | — | — | — | — | — | Eligible completed booking participant, duplication/moderation policy |
| Read public/participant-visible rating | A | A | A | A | A | A | A | A | A | A | A | Visibility/moderation policy; no hidden reporter/moderator data |
| Create complaint | A | A | A | — | C | — | — | — | C | — | — | Own/assigned relationship or staff case; evidence minimization |
| Read own complaint state | A | A | A | — | C | C | — | — | C | — | C | Reporter/respondent sees approved projection; staff assignment/purpose |
| Read assigned complaint evidence | — | — | — | — | C | A | — | — | C | — | C | Assigned case, purpose, minimum evidence, enhanced audit |
| Decide complaint outcome | — | — | — | — | — | A | — | — | C | — | — | Assigned reviewer, evidence/reason, no conflict, valid state, appeal path |
| Apply trust enforcement | — | — | — | — | — | A | — | — | C | — | — | Approved policy, proportional action, reason, dual approval where severe |
| Change quality/fraud metric definition | — | — | — | — | — | C | — | — | C | — | C | Reviewed versioned policy; no silent historical reinterpretation |
| Export complaint/trust data | — | — | — | — | — | C | — | — | — | — | C | Separate bounded approval, redaction, encryption, expiry/deletion, audit |

## Service catalog and administration

| Capability | PRV | SUP | T&S | FIN | CAT | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Create/update/deactivate service category | — | — | — | — | A | C | — | C | Catalog owner; compatibility/active-dependency impact and audit |
| Search users/providers with minimized fields | C | C | C | C | — | A | C | C | Role-specific filters/projection, purpose, pagination; no unrestricted browse |
| Read full ordinary user profile | — | — | — | — | — | — | — | — | No generic full-profile permission; use purpose-specific projections |
| Restrict/suspend ordinary account | — | — | C | — | — | A | C | — | Approved policy/reason/case; security only for compromise response |
| Impersonate user session | — | — | — | — | — | — | — | — | Prohibited by baseline; diagnostic alternatives required |
| View operational aggregate analytics | C | C | C | C | C | A | C | C | Aggregated/minimized, defined freshness and purpose; no raw-data implication |
| Export personal data in bulk | — | — | — | — | — | C | — | C | Separate export grant, independent approval, bounded scope, encryption, audit |

## Access administration and security

| Capability | PRV | SUP | T&S | FIN | CAT | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Request own/another staff role | C | C | C | C | C | C | C | C | Business justification; requester cannot self-approve |
| Grant/revoke low-risk staff role | — | — | — | — | — | — | A | C | Approved request, scope, expiry/review, audit |
| Grant/revoke high-risk role | — | — | — | — | — | — | C | C | Independent approval; no self-grant; enhanced audit/notification |
| Define permission or policy | — | — | — | — | — | — | C | C | Version-controlled reviewed change; test evidence; separation from sole deploy approval |
| Revoke compromised sessions/service identity | — | — | — | — | — | C | A | C | Incident purpose; narrow target; immediate audit/notification |
| Read security audit metadata | — | — | — | — | — | C | A | A | Security/audit purpose; payload access remains separately restricted |
| Modify/delete audit evidence | — | — | — | — | — | — | — | — | Prohibited through application roles |
| Use break-glass access | — | — | — | — | — | — | C | C | Declared incident, independent notification, step-up, time limit, post-use review |
| Access application secrets/production database | — | — | — | — | — | — | — | — | Outside application roles; separate infrastructure least-privilege controls |

## Emergency capability

| Capability | CUS | PRO | SUP | T&S | OPS | SEC | AUD | Required policy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Create emergency request | A | — | — | — | — | — | — | Customer, deliberate confirmation, supported policy/jurisdiction |
| Receive/accept priority dispatch | — | A | — | — | — | — | — | Qualified verified provider, eligibility, availability, safety controls |
| Read active emergency request/location | A | A | C | C | A | — | C | Participant or assigned operational purpose, active state, restricted projection, enhanced audit |
| Intervene/escalate under emergency policy | — | — | C | C | A | — | — | Assigned role, approved scenario, reason, legal transition, no false public-service claim |
| Export emergency data | — | — | — | — | C | — | C | Exceptional approved purpose, bounded scope, legal/privacy review, encryption, audit |

Emergency permissions do not imply medical, police, fire, or public-emergency authority. FN-063/FN-064 require legal, safety, and operational approval before implementation can claim this capability.

## Separation-of-duty conflicts

The following combinations require prevention or an approved narrowly scoped exception with independent review:

- Provider applicant/verified provider and reviewer for the same provider/application.
- Refund requester and high-value refund approver for the same transaction.
- Privileged-role requester/subject and sole approver for that grant.
- Trust complaint subject/related participant and complaint decision-maker.
- Policy author and sole production approver for a high-risk authorization change.
- Break-glass user and sole reviewer of that use.
- Data export requester and sole approver when the export contains restricted or bulk personal data.

Conflict evaluation uses authoritative relationships and case/resource IDs, not self-declaration alone.

## Matrix maintenance

- A new capability defaults to `—` for every role until this matrix and policy tests are reviewed.
- Adding a role, permission, `A`, or `C` requires a documented use case, owner, resource scope, data classification, lifecycle, audit, and test impact.
- Removing access requires rollout and revocation analysis; cached grants and active sessions must not preserve removed privilege beyond the approved delay.
- Product UI may hide unavailable controls for usability, but the backend matrix/policy remains authoritative.
- Implementations SHOULD generate or validate test cases from a machine-readable policy source once the backend toolchain is selected; this Markdown remains the reviewed human baseline until then.
