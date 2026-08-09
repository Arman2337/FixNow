# FixNow domain glossary

This glossary defines shared product language. A term describes intended meaning, not implemented behavior or an approved policy. Where policy is unresolved, the definition names the boundary instead of inventing a rule.

| Term | Definition |
| --- | --- |
| Account | A platform record through which an authorized person accesses one or more permitted capabilities. Account-to-role rules are defined by the identity model. |
| Active booking | A booking in one of the lifecycle states for which work is assigned or progressing. The exact included states must be defined in the booking lifecycle contract. |
| Administrator | A privileged actor with a specifically granted operational permission set. “Administrator” never implies unrestricted access by default. |
| AI assistance | Model-supported interpretation or recommendation that remains advisory until validated and, where consequential, confirmed by an authorized human. |
| Applicant | A provider identity that has started onboarding but is not yet eligible for normal service dispatch. |
| Assignment | The authoritative association of one eligible provider with a booking after successful atomic acceptance or another approved dispatch action. |
| Audit event | A tamper-resistant record of a security-sensitive or privileged action, including actor, action, target, time, reason where required, and outcome. It excludes secrets and unnecessary payloads. |
| Availability | A provider's declared schedule or online state, interpreted with verification, service-area, category, and conflict rules. Availability alone does not guarantee assignment. |
| Booking | The authoritative service engagement record connecting a customer request with its lifecycle, assigned provider where any, financial references, and audit history. |
| Booking event | A versioned fact emitted after an authoritative booking state change. Delivery of a notification about the event is not itself the state change. |
| Cancellation | An authorized booking transition that stops future service progress under the approved timing, reason, fee, refund, and safety policy. |
| Complaint | A controlled trust-and-safety case raised about a participant, booking, payment, or platform outcome, with evidence, lifecycle, ownership, and appeal rules. |
| Customer | A person authorized to discover services, create requests, participate in their own bookings, make applicable payments, and provide eligible feedback. |
| Emergency request | A deliberately confirmed, policy-bounded high-priority service request. It is not a replacement for public emergency services and cannot imply guaranteed response. |
| Eligibility | The complete set of current rules that must be satisfied before an actor or resource may participate in an action, such as provider verification, category skill, availability, coverage, account state, and safety restrictions. |
| ETA | A time estimate based on available location and routing information. It is not a guarantee and must expose stale or unavailable states. |
| Evidence | Information attached to a verification, complaint, payment, or safety process whose access, authenticity limits, retention, and disclosure require explicit policy. |
| External provider | A third party supplying an isolated capability such as identity, payment, maps, storage, notification delivery, or AI. It is not trusted as the platform's domain authority. |
| Fraud signal | A reviewable indicator of possible abuse. A signal is not proof and must not autonomously impose a consequential penalty without approved policy. |
| Idempotency | The property that safely retrying the same identified operation does not create unintended duplicate effects. |
| KYC | Identity or qualification checks required by an approved provider-onboarding policy. The specific documents and legal basis remain jurisdiction- and category-dependent. |
| Live location | A recent, purpose-limited location update used during explicitly permitted states. It must have freshness, precision, consent or lawful-basis, access, and retention limits. |
| Manual fallback | A non-AI or non-vendor-dependent path that lets a user continue or receive a clear outcome when an assisted capability is unavailable. |
| Matching | The deterministic process of finding and ordering providers who satisfy current eligibility rules for a service request. Matching does not itself assign a provider. |
| Notification | A delivery attempt through a user-facing channel based on an authoritative event. A notification is not the source of truth for domain state. |
| OTP | A short-lived one-time code used for an approved verification or authentication purpose, protected by expiry, retry limits, and non-disclosure controls. |
| Payment order | A booking-related instruction created through the approved payment adapter whose final state must be verified by the backend. |
| Permission | An explicitly granted ability to perform an action on a resource under defined conditions. Permissions are enforced at trusted backend boundaries. |
| Precise location | Location data detailed enough to identify or closely infer a person's position, home, route, or workplace and therefore requiring heightened protection. |
| Provider | A general term for a provider applicant or verified provider. Requirements use the more specific term whenever eligibility matters. |
| Provider verification | The auditable review workflow that determines whether an applicant meets approved requirements for specified services and jurisdictions. |
| Rating | A bounded score submitted by an eligible booking participant under the approved one-or-more-rating and aggregation policy. |
| Real-time update | A low-latency delivery of current information. Clients must reconcile it with authoritative backend state after gaps or reconnects. |
| Reconciliation | The process of comparing internal records with an external provider or authoritative source and resolving mismatches without erasing history. |
| Refund | A controlled financial operation returning all or part of an eligible payment while preserving the original transaction and audit records. |
| Review | Textual or structured feedback associated with an eligible rating and subject to moderation and visibility policy. “Review” may also describe an administrative assessment; context must disambiguate it. |
| Role | A named grouping used to help assign permissions. A role is not a substitute for resource ownership, account state, or contextual authorization checks. |
| Service area | The approved geographic coverage within which a provider may be considered for matching, represented with the precision and method selected by the location architecture. |
| Service category | A versionable platform-managed classification of work used for discovery, provider skills, matching, policy, and reporting. |
| Service history | An authorized, paginated view of past bookings and their permitted summary information; it is not an unrestricted copy of all event or personal data. |
| Service request | A customer's explicit request for help, containing the minimum approved category, description, location, timing, and consent information before provider assignment. |
| Skill | An approved association indicating that a provider may be considered for a service category, subject to verification and other eligibility rules. |
| Support role | A constrained privileged role for assigned support workflows. It does not automatically inherit all administrator permissions. |
| Transaction | An immutable financial record of an attempted or completed monetary operation and its verified state transitions. |
| Trust boundary | A point where data or control crosses between actors, processes, applications, networks, or providers with different trust assumptions and therefore requires validation and authorization. |
| Verified provider | A provider whose current verification state permits participation in specified services, subject to all other eligibility rules. Verification does not guarantee availability or assignment. |
| Webhook | An externally initiated request reporting a provider event. It must be authenticated or signature-verified, replay-protected, validated, and processed idempotently. |

## Usage rules

- Use the most specific defined term in contracts, task descriptions, code, and user-facing copy.
- Do not use “job,” “request,” and “booking” interchangeably: a service request precedes assignment; a booking is the authoritative lifecycle record; “job” is informal provider-facing language unless a future specification defines it separately.
- Do not use “verified,” “available,” “matched,” “assigned,” and “online” interchangeably; each represents a different condition.
- Add or change a term when domain meaning changes, and update affected requirements and contracts in the same task.
- Major policy or architectural decisions belong in the appropriate specification or ADR, not in a glossary definition.
