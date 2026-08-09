# FixNow product requirements

## Document status

- Status: Draft for stakeholder review
- Last updated: 2026-08-09
- Scope: Product requirements and constraints, not implementation design
- Related: [Domain glossary](glossary.md), [system architecture](../architecture/README.md), and [project tasks](../../PROJECT_TASKS.md)

This document turns the planned FixNow concept into reviewable requirements without treating unresolved business, legal, operational, or technical questions as decisions. Requirements use stable identifiers so later specifications and tests can reference them.

## Product intent

FixNow is intended to connect a customer who needs a location-based service with an eligible provider, support the resulting booking through completion, and give authorized administrators the tools needed to operate the marketplace safely. The product may later use AI to assist understanding and recommendations, but deterministic rules and explicit human actions remain authoritative for consequential operations.

### Goals

- Help a customer describe a need, discover an appropriate service, request help, and understand booking progress.
- Help an eligible provider manage onboarding, availability, incoming work, service progress, and earnings information.
- Give authorized administrators auditable controls for provider verification, marketplace configuration, disputes, and operational oversight.
- Protect identity, location, payment, KYC, and safety-related information throughout its lifecycle.
- Degrade safely when providers, networks, notification channels, payment services, maps, or AI services are unavailable.

### Non-goals for the initial product definition

- FixNow is not defined as an employer, public emergency service, medical service, law-enforcement service, or guarantee of provider response.
- The platform does not diagnose hazards or replace qualified professional judgment.
- AI output does not autonomously create a booking, approve a provider, set a final price, settle a payment, resolve a complaint, or penalize an account.
- Exact service categories, launch geography, commercial terms, service-level targets, and supported languages remain undecided.

## Actors and boundaries

| Actor | Responsibility | Boundary |
| --- | --- | --- |
| Customer | Maintains an account, discovers services, creates and manages requests, pays where required, and provides feedback. | Can access only data and actions authorized for that customer. |
| Provider applicant | Registers and supplies the profile, skill, service-area, and verification information required for review. | Cannot receive normal work until the approved verification policy permits it. |
| Verified provider | Manages availability, receives eligible work, progresses accepted bookings, and views authorized earnings information. | Cannot access unrelated customer data or perform admin actions. |
| Administrator | Performs explicitly granted operational actions such as provider review, service management, support, and complaint handling. | Every privileged action requires backend authorization and an audit record. |
| Support or reviewer role | Handles only the operational subset assigned by the permission model. | Must not inherit unrestricted administrator access by default. |
| Platform service | Enforces contracts, permissions, workflows, persistence, and integrations. | External and AI output is untrusted until validated. |
| External provider | Supplies an approved capability such as payments, notifications, maps, storage, identity, or AI. | Must be isolated behind an adapter, receive minimum necessary data, and fail safely. |

The authoritative role and permission matrix will be defined by FN-013. This document does not grant permissions merely by naming an actor.

## Core journeys

### Customer journey

1. Register or sign in through an approved identity flow.
2. Maintain only the profile data required for the service.
3. Grant, deny, or revoke location permission with a clear explanation of consequences.
4. Browse services or describe an issue and review any assisted recommendation.
5. Enter request details, location, timing, and required confirmations.
6. Review available price or estimate information and submit the request explicitly.
7. Receive a clear no-provider, delayed, accepted, cancelled, or failed outcome.
8. Track an accepted booking only while policy permits and progress it with the assigned provider.
9. Complete payment when applicable and receive an accurate transaction record.
10. View service history and submit eligible feedback or a complaint.

### Provider journey

1. Register as a provider applicant.
2. Supply profile, skills, service coverage, and required verification documents.
3. See verification state and actionable rejection or resubmission information where policy permits.
4. Configure availability and intentionally go online or offline.
5. Receive only eligible requests with the minimum customer information needed to decide.
6. Accept one request atomically or receive a clear already-assigned outcome.
7. Navigate to an active job using an approved mapping flow and consented location sharing.
8. Progress the booking through allowed states and record completion.
9. View booking history, transaction status, earnings information, and received ratings as authorized.
10. Raise a complaint or appeal through the defined trust process.

### Administrator journey

1. Authenticate with controls appropriate to privileged access.
2. Access only functions granted to the administrator's role.
3. Review provider information and private documents through controlled, logged access.
4. Approve, reject, suspend, or request resubmission only through legal workflow transitions.
5. Manage service taxonomy and inspect users or bookings using minimized data views.
6. Handle complaints, refunds, or other interventions through reasoned, auditable actions.
7. Review operational aggregates without unrestricted access to raw personal data.

### Emergency-request journey

1. The customer sees clear language about the capability's limits and appropriate public emergency alternatives.
2. The customer deliberately confirms the request and any necessary location sharing.
3. The platform validates eligibility, prioritizes dispatch under the approved policy, and reports progress honestly.
4. If no provider is available or delivery fails, the customer receives explicit fallback guidance rather than a false success state.
5. The customer can cancel where safe and permitted; all high-risk transitions are auditable.

The meaning of “emergency,” supported scenarios, launch jurisdictions, provider qualifications, escalation path, and response claims require legal, safety, and operational approval before this capability can ship.

## Functional requirements

### Accounts and identity

- **FR-ID-001:** The platform must distinguish customer, provider-applicant, verified-provider, administrator, support/reviewer, and service identities according to an approved permission model.
- **FR-ID-002:** Registration, login, verification, session renewal, logout, and recovery flows must not disclose whether unrelated identity data exists beyond approved product behavior.
- **FR-ID-003:** Account state changes and privileged authentication events must be auditable without storing credentials or raw authentication material.
- **FR-ID-004:** A user must be able to access correction, export, deactivation, and deletion paths required by the approved privacy policy and applicable law.

### Customer experience

- **FR-CUS-001:** A customer must be able to maintain approved profile fields and see validation errors that identify a corrective action.
- **FR-CUS-002:** A customer must be able to grant or deny location access and still receive a defined manual-location or unsupported-flow outcome.
- **FR-CUS-003:** A customer must be able to discover active service categories without seeing inactive or unauthorized offerings.
- **FR-CUS-004:** A customer must explicitly review and submit each service request; retries must not silently create duplicates.
- **FR-CUS-005:** A customer must be able to view authorized active and historical booking information, payment records, feedback, and complaint state.

### Provider experience

- **FR-PRO-001:** A provider applicant must be able to maintain required profile, skill, service-area, and verification information.
- **FR-PRO-002:** Verification documents must be private, validated, retained only as approved, and accessible only to authorized reviewers and services.
- **FR-PRO-003:** Verification decisions must use explicit legal transitions, reasons, reviewer attribution, timestamps, and immutable audit history.
- **FR-PRO-004:** A verified provider must control schedule and online availability, subject to conflict and eligibility rules.
- **FR-PRO-005:** A provider must receive only requests for which category, verification, service area, and availability rules make the provider eligible.
- **FR-PRO-006:** Acceptance must be atomic so no more than one provider becomes assigned through a race.
- **FR-PRO-007:** A provider must be able to progress an assigned booking only through authorized lifecycle transitions.
- **FR-PRO-008:** A provider must be able to view authorized job history, earnings records, ratings, and complaint or appeal state.

### Services, requests, and bookings

- **FR-BKG-001:** Administrators with the required permission must manage a versionable service taxonomy without corrupting historical bookings.
- **FR-BKG-002:** A service request must capture the minimum category, description, location, timing, and consent data required by the approved service policy.
- **FR-BKG-003:** Matching must exclude providers who are unverified, unavailable, outside service coverage, inactive, or otherwise ineligible.
- **FR-BKG-004:** Booking lifecycle transitions, actors, timestamps, reasons, and emitted events must be defined and validated centrally.
- **FR-BKG-005:** Cancellation eligibility and consequences must be shown before confirmation and applied consistently to customer and provider actions.
- **FR-BKG-006:** A no-match, timeout, integration failure, or stale result must produce an explicit recoverable outcome rather than a false booking state.

### Real-time and location

- **FR-LOC-001:** Collection of precise location must have a stated purpose, consent or other approved lawful basis, bounded precision, and retention period.
- **FR-LOC-002:** Provider presence and location must become stale or unavailable after a defined timeout and must never imply freshness without evidence.
- **FR-LOC-003:** Live booking tracking must be visible only to authorized booking participants and only during policy-approved lifecycle states.
- **FR-LOC-004:** Real-time clients must recover from disconnects by reconciling with authoritative backend state rather than assuming event delivery.
- **FR-LOC-005:** ETA values must be labeled as estimates and provide an unavailable or stale state.

### Payments and financial records

- **FR-PAY-001:** The backend, not a client assertion, must verify every consequential payment outcome with the approved payment provider.
- **FR-PAY-002:** Payment creation and callback handling must be idempotent and preserve exact currency and amount semantics.
- **FR-PAY-003:** Transactions, refunds, invoices, and provider earnings must preserve immutable financial history and authorization boundaries.
- **FR-PAY-004:** Users must see pending, failed, completed, refunded, and reconciliation-required states accurately.
- **FR-PAY-005:** The platform must not store payment data prohibited by the approved provider or compliance model.

### Ratings, complaints, and trust

- **FR-TRU-001:** Only an eligible participant in a qualifying booking may submit the allowed rating or review.
- **FR-TRU-002:** Complaints must have controlled evidence access, lifecycle states, assigned ownership, reasons, timestamps, and audit history.
- **FR-TRU-003:** Provider quality metrics must have documented definitions and must not silently change historical interpretation.
- **FR-TRU-004:** Fraud or abuse signals must be explainable to authorized reviewers and must not autonomously impose a consequential penalty without approved policy.
- **FR-TRU-005:** Reporting, appeal, correction, and moderation paths must protect parties from unnecessary identity disclosure.

### Administration

- **FR-ADM-001:** Every admin capability must enforce backend authorization independently of navigation visibility.
- **FR-ADM-002:** Admin searches and detail views must minimize personal data and use pagination and bounded filters.
- **FR-ADM-003:** Privileged changes must record actor, action, target, reason, timestamp, and outcome in a tamper-resistant audit trail.
- **FR-ADM-004:** Destructive or financially consequential actions must require explicit confirmation and any additional approval required by policy.
- **FR-ADM-005:** Analytics must define source, time window, freshness, exclusions, and aggregation so operators do not mistake incomplete data for exact truth.

### Notifications

- **FR-NOT-001:** Notifications must be derived from authoritative domain events and must not be the only record of booking state.
- **FR-NOT-002:** Device tokens, preferences, consent, invalid-token cleanup, retries, and deduplication must be managed explicitly.
- **FR-NOT-003:** Lock-screen content must avoid sensitive personal, location, financial, KYC, complaint, or emergency detail by default.
- **FR-NOT-004:** Critical delivery failures must be observable and use an approved fallback where one exists.

### AI assistance

- **FR-AI-001:** AI inputs must be minimized, approved for the purpose, and protected from prompt or content injection at trust boundaries.
- **FR-AI-002:** Classification, recommendation, voice, translation, image, price, and fraud outputs must conform to validated schemas and support abstention.
- **FR-AI-003:** A user must review consequential AI-assisted interpretations before they affect a request or booking.
- **FR-AI-004:** AI features must have versioned evaluation data, quality thresholds, latency and cost limits, bias review where applicable, and deterministic fallback.
- **FR-AI-005:** AI availability must not prevent core manual flows unless stakeholders explicitly approve and document that dependency.

### Emergency capability

- **FR-EMG-001:** Emergency entry must clearly distinguish FixNow from public emergency services and show jurisdiction-appropriate guidance approved before launch.
- **FR-EMG-002:** Request creation must require deliberate confirmation while remaining accessible under stressful conditions.
- **FR-EMG-003:** Priority dispatch must follow explicit eligibility and abuse controls without bypassing provider qualification or safety rules.
- **FR-EMG-004:** No-provider, timeout, offline, cancellation, and notification-failure outcomes must have approved customer guidance.
- **FR-EMG-005:** Emergency data access and lifecycle events must be minimized, tightly authorized, retained under policy, and auditable.

## Non-functional requirements

Numeric targets remain `TBD` until product, operations, budget, and risk owners approve them. A missing target is an open decision, not permission to omit measurement.

### Architecture and maintainability

- **NFR-ARC-001:** Mobile, backend, admin, shared, infrastructure, and AI code must retain the dependency boundaries in the architecture overview.
- **NFR-ARC-002:** Cross-application communication must use documented, versioned contracts; applications must not import another application's private source.
- **NFR-ARC-003:** Domain rules must remain separable from UI, transport, persistence, and vendor adapters where practical.
- **NFR-ARC-004:** Hard-to-reverse framework, provider, database, identity, protocol, or infrastructure choices require accepted ADRs.

### Security

- **NFR-SEC-001:** All untrusted input must be validated at its trust boundary and output encoded for its destination.
- **NFR-SEC-002:** Authentication material, secrets, KYC files, precise location, payment events, and privileged actions require least-privilege access and protection in transit and at rest.
- **NFR-SEC-003:** Authorization must be deny-by-default and tested across role, ownership, account state, and high-risk action boundaries.
- **NFR-SEC-004:** Public and high-risk endpoints require approved abuse controls, rate limits, replay protection, and security monitoring.
- **NFR-SEC-005:** Security events and admin actions must be auditable without logging secrets or unnecessary sensitive payloads.

### Privacy and data governance

- **NFR-PRI-001:** Each personal-data field must have a documented purpose, owner, access policy, retention period, deletion behavior, and lawful basis or approved consent model.
- **NFR-PRI-002:** The system must minimize collection and disclosure, especially for KYC, precise location, complaints, payment data, emergency requests, images, audio, and AI inputs.
- **NFR-PRI-003:** Non-production environments and evaluation datasets must not contain unapproved production personal data.
- **NFR-PRI-004:** Export, correction, deletion, legal hold, and audit-retention conflicts must be resolved by approved policy before production.

### Reliability and availability

- **NFR-REL-001:** Product owners must define availability and recovery targets for core booking, emergency, identity, payment, and admin capabilities before production (`TBD`).
- **NFR-REL-002:** Network and vendor calls must use bounded timeouts, retry only safe operations, and use idempotency where duplicate execution is harmful.
- **NFR-REL-003:** Health signals must distinguish process liveness from dependency-aware readiness without exposing sensitive topology.
- **NFR-REL-004:** Backups and restoration must be tested against approved recovery point and recovery time objectives (`TBD`).
- **NFR-REL-005:** Clients must present honest offline, stale, delayed, partial, and failed states.

### Performance and scale

- **NFR-PER-001:** Owners must approve latency objectives for request creation, matching, booking commands, real-time updates, and admin search before load testing (`TBD`).
- **NFR-PER-002:** Expected launch geography, customer/provider concurrency, booking volume, location-update frequency, notification volume, and data growth must be quantified (`TBD`).
- **NFR-PER-003:** Pagination, bounded queries, backpressure, and load shedding must protect shared resources.

### Accessibility and usability

- **NFR-ACC-001:** Customer, provider, and admin flows must meet the approved accessibility standard and target level (`TBD`, candidate: WCAG 2.2 AA where applicable).
- **NFR-ACC-002:** Critical flows must support keyboard/switch navigation where applicable, screen readers, sufficient contrast, scalable text, and clear error recovery.
- **NFR-ACC-003:** Emergency and payment confirmations must be deliberate without relying only on color, motion, or time-limited interaction.

### Observability and operations

- **NFR-OPS-001:** Logs, metrics, traces, and audit events must use correlation identifiers while excluding secrets and unnecessary personal data.
- **NFR-OPS-002:** Alerts must map to an owned runbook and distinguish customer impact from noisy dependency signals.
- **NFR-OPS-003:** Deployments and migrations must have compatibility, rollback, and verification plans appropriate to their risk.

### Cost and external dependencies

- **NFR-CST-001:** Each hosted dependency must have an owner, approved budget, usage limits, failure behavior, data-processing review, and exit strategy.
- **NFR-CST-002:** Payment, notification, maps, storage, identity, and AI usage must expose cost/volume telemetry before production.
- **NFR-CST-003:** AI features must enforce per-request and aggregate cost limits and offer a manual fallback where required by FR-AI-005.
- **NFR-CST-004:** Environments must prevent accidental production-scale spend through least privilege, quotas, and explicit provisioning approval.

## Data classes requiring focused review

| Data class | Examples | Minimum requirement before implementation |
| --- | --- | --- |
| Identity and contact | Name, phone, email, authentication identifiers | Purpose, verification policy, access, retention, account lifecycle |
| Precise location | Customer request point, provider live GPS, routes | Consent/lawful basis, precision, active-use states, retention, disclosure limits |
| Provider verification | Identity and qualification documents, review reasons | Approved required documents, private storage, reviewer access, malware controls, deletion policy |
| Booking | Description, category, participants, lifecycle events | Ownership, minimization, history policy, audit and dispute needs |
| Financial | Orders, transactions, refunds, invoices, earnings | Provider/compliance model, immutable records, retention, reconciliation, access |
| Trust and safety | Complaints, evidence, ratings, fraud signals | Evidence access, reporter protection, appeals, retention, human review |
| Media and AI | Text, audio, images, transcripts, prompts, model output | Consent, provider terms, minimization, deletion, evaluation use, human confirmation |
| Emergency | Request, location, dispatch events, safety messages | Legal and safety approval, strict authorization, retention, escalation and fallback |

## Release boundaries

A capability is not ready for production merely because its implementation task is complete. Before production, the relevant product decision, security/privacy controls, tests, operational ownership, monitoring, support procedure, and rollback path must be approved. Emergency, payments, KYC, precise location, privileged administration, and consequential AI require focused review.

## Open decisions and stakeholder questions

| ID | Decision required | Why it matters | Required owners/evidence |
| --- | --- | --- | --- |
| OD-001 | Initial launch country, regions, and service hours | Controls legal duties, maps, language, tax, payments, emergencies, and support coverage | Product, legal, operations |
| OD-002 | Initial customer segments and provider/service categories | Defines the smallest useful launch scope and qualification needs | Product research and operations |
| OD-003 | Marketplace operating model and relationship to providers | Affects contracts, liability, verification, pricing, payouts, and disputes | Legal, finance, operations |
| OD-004 | Supported platforms, OS/browser versions, and accessibility target | Determines implementation and test matrix | Product, design, engineering |
| OD-005 | Identity attributes, verification channels, recovery, MFA, and provider | Determines security, privacy, cost, and account lifecycle | Security, product, legal; ADR for provider |
| OD-006 | Provider KYC/qualification documents and review policy by category/jurisdiction | Determines sensitive-data collection and eligibility | Legal, trust/safety, operations |
| OD-007 | Service taxonomy ownership and change policy | Prevents incompatible booking and reporting history | Product, operations, data |
| OD-008 | Pricing model, estimates, platform fees, taxes, cancellation fees, and provider earnings | Controls customer consent, payments, refunds, invoices, and reporting | Product, finance, legal |
| OD-009 | Payment methods, settlement/payout model, refund policy, and provider | Controls compliance, reconciliation, credentials, and data boundaries | Finance, legal, security; ADR for provider |
| OD-010 | Location precision, maps/navigation provider, retention, and sharing rules | Controls privacy, cost, matching, ETA, and safety | Product, privacy, security; ADR for provider |
| OD-011 | Definition and scope of “emergency,” public-service guidance, provider qualification, and escalation | High safety and liability impact | Legal, safety, product, operations |
| OD-012 | Notification channels, critical-message fallback, quiet hours, and provider | Controls reliability, privacy, cost, and consent | Product, privacy, operations; ADR for provider |
| OD-013 | Complaint categories, evidence rules, response targets, appeals, and enforcement | Controls fairness, support staffing, data retention, and trust | Trust/safety, legal, operations |
| OD-014 | Rating eligibility, moderation, aggregation, and visibility | Controls fairness and provider quality signals | Product, trust/safety, data |
| OD-015 | AI features allowed at launch, model providers, supported languages, quality thresholds, and human review | Controls privacy, safety, cost, bias, and fallback | Product, AI, privacy, security; ADRs as needed |
| OD-016 | Personal-data retention, deletion, export, legal holds, and data residency | Required for privacy design and storage architecture | Legal/privacy, security, data |
| OD-017 | Availability, recovery, latency, scale, and support objectives | Drives architecture, staffing, monitoring, and cost | Product, engineering, operations, finance |
| OD-018 | Cloud environments, regions, budget ceilings, and operational ownership | Drives deployment architecture and ongoing cost | Engineering, security, operations, finance; ADR |
| OD-019 | Analytics definitions, freshness, access, and acceptable data use | Prevents misleading metrics and overexposure of personal data | Product, data, privacy, operations |
| OD-020 | Account suspension, deletion, provider offboarding, and active-booking handling | Prevents orphaned workflows and unauthorized access | Product, trust/safety, legal, operations |

## Review checklist

- [ ] Product owners approve the goals, non-goals, actors, and launch boundaries.
- [ ] Operations validates that customer, provider, admin, complaint, and emergency journeys are supportable.
- [ ] Security and privacy owners review the data classes, trust boundaries, and control requirements.
- [ ] Legal reviews provider operating model, KYC, location, payment, emergency, complaint, retention, and AI implications.
- [ ] Engineering confirms requirements are testable and identifies ADRs needed before implementation.
- [ ] Each open decision has a named accountable owner and target resolution point before its dependent task starts.

Until those reviews occur, this document is a requirements baseline for planning rather than final policy approval.
