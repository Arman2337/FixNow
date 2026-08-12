# Security and privacy architecture

## Status and scope

This document defines FixNow's system-wide security and privacy controls, data governance, abuse defenses, incident expectations, and verification gates. It is normative architecture, not evidence that controls or product features are implemented.

Related documents:

- [Threat model and risk register](threat-model.md)
- [Identity, roles, and permissions](identity-and-access.md)
- [Permission matrix](permission-matrix.md)
- [Data and storage architecture](../architecture/data-architecture.md)
- [API conventions](../architecture/api-conventions.md)
- [Product requirements and open decisions](../product/requirements.md)
- [Vulnerability reporting policy](../../SECURITY.md)

Applicable laws, launch jurisdictions, data-controller/processor roles, lawful bases, exact retention periods, recovery targets, vendors, and production risk acceptance remain unresolved. No processing of real customer/provider data is approved until the relevant gates in this document have named accountable owners and evidence.

## Objectives

1. Prevent unauthorized access, privilege escalation, data disclosure, tampering, fraud, and unsafe domain actions.
2. Minimize identity, KYC, precise location, payment, complaint, emergency, media, and AI data throughout collection, use, sharing, retention, and deletion.
3. Preserve booking, verification, payment, trust, authorization, and audit integrity under concurrency, retry, dependency failure, and malicious input.
4. Contain compromise through least privilege, environment isolation, short-lived credentials, network boundaries, and safe failure.
5. Make high-risk behavior observable and auditable without turning telemetry into a sensitive-data copy.
6. Provide tested detection, containment, recovery, notification, and learning for security/privacy incidents.

## Security and privacy governance

| Role | Accountable responsibilities |
| --- | --- |
| Product owner | Purpose, necessity, user expectations, launch scope, safe fallback, and risk acceptance with required reviewers |
| Security owner | Threat model, control requirements, security review, vulnerability handling, assurance evidence, and incident security lead |
| Privacy/legal owner | Jurisdiction, controller/processor roles, lawful basis/consent, notices, rights, retention, residency, vendor terms, and breach obligations |
| Domain engineering owner | Secure design/implementation, tests, migrations, operational telemetry, runbooks, and remediation for owned capabilities |
| Platform/operations owner | Environment isolation, secrets, identity/network controls, deployment, monitoring, backup/restore, and infrastructure response |
| Trust and safety owner | Abuse policy, complaints/evidence, enforcement fairness, appeals, emergency misuse, and investigator access |
| Finance owner | Payment/refund/reconciliation controls, monetary limits, financial retention, and provider/compliance coordination |
| AI owner | Model/provider data flow, evaluation, prompt/content threats, output validation, human review, cost, and AI incident response |

- High-risk acceptance requires the accountable product owner plus security and privacy/legal review; finance, trust/safety, AI, or operations join when their domain is affected.
- A builder or task author cannot solely accept a high-impact residual risk created by their own implementation.
- Risk acceptance is time-bounded, records rationale, compensating controls, owner, expiry/review date, and remediation task.
- “TBD” is a production blocker for the affected processing or capability, not permission to select a convenient default.

## Trust boundaries and data flow

```text
Untrusted/public networks and devices
  ├─ Customer/provider mobile app
  ├─ Administrator browser
  └─ External callbacks/webhooks
              │ HTTPS; untrusted input and client state
              ▼
Edge/API boundary
  ├─ request limits and protocol validation
  ├─ authentication and abuse controls
  └─ correlation without sensitive identifiers
              │ authenticated principal; still policy-constrained
              ▼
Backend trust boundary
  ├─ centralized authorization and domain invariants
  ├─ API/workflow validation and audit
  └─ adapters with timeouts, idempotency, and safe mapping
       │              │                    │
       ▼              ▼                    ▼
 PostgreSQL       Redis (ephemeral)   Private object storage
 authority        never authority     quarantined artifacts
       │
       ├──────────── approved minimal data ────────────┐
       ▼                                                ▼
 External providers                               AI boundary
 payment/identity/maps/notifications              model input/output
 untrusted responses and callbacks                untrusted output

Operations plane (separate privileged boundary)
  CI/CD, secrets, cloud control plane, monitoring, backup/restore,
  break-glass access, and incident tooling
```

### Boundary rules

- Device/browser integrity is never assumed. Local validation and secure storage improve usability/defense but backend controls remain authoritative.
- Admin network location or VPN is not sufficient authorization; privileged identity, policy, step-up, and audit still apply.
- Every external response, webhook, file, event, model output, and cached value is untrusted until authenticated where applicable, schema-validated, authorized, and mapped to domain rules.
- Backend components do not inherit trust merely because they share a network. Service identity and least-privilege authorization apply at internal boundaries.
- Operations-plane access is separate from application roles and cannot be reached through ordinary customer/provider/admin permissions.
- Cross-environment identity, credentials, data, object URLs, queues, caches, backups, and network access are prohibited by default.

## Data protection model

### Data inventory and approval register

| Data class | Purpose boundary | Baseline classification | Collection/processing gate | Retention gate | Primary owners |
| --- | --- | --- | --- | --- | --- |
| Identity/contact | Account access, verified communication, support | Confidential; auth material Restricted | Required attributes, verification channel, lawful basis/notice, account-linking and recovery policy `TBD` | Account lifecycle, fraud/legal need, deletion/anonymization `TBD` | Product, identity engineering, privacy/legal, security |
| Provider KYC/qualifications | Determine service eligibility under approved policy | Restricted | Required documents by service/jurisdiction, reviewer purpose, vendor/subprocessor, lawful basis `TBD` | Rejected/expired/approved/offboarded/legal-hold periods `TBD` | Trust/operations, privacy/legal, security |
| Service request/booking | Match and deliver requested service, support/dispute | Confidential; sensitive fields Restricted | Minimum description, category, timing, participant disclosures and notices `TBD` | Active/history/dispute/financial dependency periods `TBD` | Booking product/engineering, privacy/legal |
| Precise provider location | Active navigation/tracking for an accepted booking in the `On The Way`/active-travel state | Restricted | Versioned notice and consent/permission evidence; configurable minimum necessary precision; foreground/background collection only for the active-job purpose; manual status/call/chat fallback | Latest point only in ephemeral cache, expiring no later than the initial 60-second stale threshold and invalidated when tracking authority ends; no MVP route history | Product, location engineering, privacy/legal, security |
| Payment/financial | Orders, verification, refunds, invoices, earnings, reconciliation | Restricted | Provider/compliance scope, fields, notices, tax/financial obligations `TBD` | Transaction/invoice/refund/legal periods `TBD` | Finance, payments engineering, privacy/legal, security |
| Ratings/reviews | Participant feedback and provider quality | Confidential/public subset | Eligibility, visibility, moderation, lawful use `TBD` | Account/booking relationship and moderation history `TBD` | Product, trust/safety, privacy/legal |
| Complaints/evidence | Investigate and resolve safety/trust disputes | Restricted | Categories, evidence rules, participant notices, investigator purpose, appeal `TBD` | Case, appeal, enforcement and legal periods `TBD` | Trust/safety, privacy/legal, security |
| Emergency data | Priority request, dispatch, safety messaging, operational response | Restricted | Supported scenarios/jurisdictions, legal authority, disclaimers, escalation and access `TBD` | Minimum operational/safety/legal period `TBD` | Safety/product, operations, privacy/legal, security |
| Media/audio/images | Describe issue, evidence, voice/image assistance | Restricted unless explicitly published | File/content limits, consent/notice, bystander data, metadata stripping, AI/vendor use `TBD` | Purpose-specific deletion and derived-data handling `TBD` | Product, storage/AI, privacy/legal, security |
| AI inputs/outputs/evaluations | Advisory understanding/recommendation/translation/analysis | Restricted when sourced from user/domain data | Approved features/provider, minimization, training-use prohibition/terms, human review `TBD` | Prompt/output/provider/evaluation retention `TBD` | AI, product, privacy/legal, security |
| Device/notification | Deliver notifications and manage devices/preferences | Confidential | Channel/provider, consent/permission, lock-screen minimization `TBD` | Invalid-token cleanup, opt-out and inactivity periods `TBD` | Notifications engineering, privacy/legal |
| Security/operations telemetry | Detect, diagnose, audit, respond, improve reliability | Confidential; selected audit/security evidence Restricted | Event necessity, fields, redaction, access, alert purpose | Log/trace/metric/audit retention by class `TBD` | Security, operations, privacy/legal |

Before a field or object is implemented, its owner MUST add it to a reviewed inventory/schema with purpose, classification, source, recipients/processors, access policy, environment, residency, retention trigger/duration, deletion behavior, legal hold, rights impact, and audit requirements.

### Minimization and purpose limitation

- Collect a field only when a documented product/control purpose cannot be met with less or coarser data.
- Optional fields default to absent; preselection and forced consent for unrelated purposes are prohibited.
- Precise location is reduced to the least precision and shortest active state that meets matching/navigation/safety requirements.
- File metadata such as EXIF/geolocation is stripped or retained only under explicit approved purpose.
- Derived, aggregated, hashed, tokenized, redacted, cached, logged, exported, and AI-processed data remains personal/sensitive when re-identification or linkage is reasonably possible.
- Data collected for service delivery cannot silently become advertising, model training, employee surveillance, or unrelated analytics input.
- Production data is prohibited in development, tests, demos, support screenshots, issue trackers, prompts, or evaluation datasets without a separately approved protected process.

### Consent, notice, and preference evidence

Consent is used only when privacy/legal confirms it is the appropriate basis. The system MUST NOT label a forced product requirement as freely given consent.

Where consent or permission is required:

- Present specific purpose, data class, recipient/provider category, duration/withdrawal consequence, and meaningful alternative before collection.
- Separate unrelated purposes and avoid bundled, prechecked, manipulative, or unequal choices.
- Record policy/notice version, purpose code, actor, time, locale, decision, source surface, and withdrawal/change evidence without copying unnecessary payloads.
- Re-consent when purpose or recipients materially change; cosmetic text changes do not reset history.
- Withdrawal is as accessible as grant and stops future processing promptly, while clearly explaining retained legal/contractual records.
- Mobile OS permission is necessary but not sufficient product consent/purpose authorization. Backend lifecycle and preference policy still applies.
- Denied/revoked location, notification, microphone, camera, or media permission produces a documented fallback or an honest unsupported outcome.

For OD-010 provider live tracking, the notice MUST explain why precise location is needed, when collection starts and stops, who can see it, Google Maps Platform processing, and that FixNow does not continuously track providers outside the defined active-job flow. Revocation immediately stops transmission and invalidates the live projection; it does not by itself cancel the booking. Customers receive “Live location unavailable,” while manual status, call, chat, and service flows continue where possible.

### Individual rights and account lifecycle

- Provide authenticated, abuse-resistant routes for access, correction, export, objection/restriction where applicable, deactivation, and deletion.
- Rights responses verify identity proportionally without collecting excessive new data or exposing another person/complainant/provider.
- Exports are bounded, encrypted, short-lived, purpose-audited, and exclude secrets, internal abuse controls, another party's protected data, and legally restricted evidence.
- Deletion is a workflow across PostgreSQL, objects/versions, caches, search/analytics copies, vendors, derived data, exports, and backup-restoration controls.
- Legal hold and mandatory retention are explicit exceptions with owner, authority, scope, expiry/review, access limit, and user communication where permitted.
- Restored backups must reapply deletion/tombstone and current access state before serving traffic.

## Security control architecture

### Client applications

- Store only minimum local data; secrets and server credentials never ship in clients.
- Authentication/session material uses platform-protected storage selected during implementation and is cleared/revoked according to lifecycle.
- Sensitive screens, clipboard, screenshots, notifications, deep links, logs, backups, and background previews require threat-specific review.
- Deep links, intents, custom schemes, files, QR codes, push payloads, and web content are untrusted and validated before navigation/action.
- Certificate validation cannot be disabled. Pinning, if proposed, requires an ADR covering rotation, recovery, and availability tradeoffs.
- Root/jailbreak/debugger/device-integrity signals MAY inform risk but MUST NOT be the sole authorization control or automatically deny accessibility-compatible users without approved policy.
- Offline state never authorizes a consequential server action; reconnect reconciles with authoritative backend state.

### API and backend

- Follow the [API conventions](../architecture/api-conventions.md), centralized [authorization model](identity-and-access.md), and safe [error conventions](../architecture/error-response-conventions.md).
- Validate syntax, schema, size, encoding, normalization, media type, content, and domain preconditions before side effects.
- Parameterize database access; allowlist dynamic fields; encode output for its destination; prevent mass assignment and unsafe deserialization.
- State-changing requests protect against replay/duplication with transaction invariants and idempotency where required.
- Browser-based privileged flows require approved CSRF defenses, secure cookie/session settings, origin policy, clickjacking protection, and content security policy.
- CORS is deny-by-default with exact approved origins/methods/headers; wildcard credentialed access is prohibited.
- SSRF defenses use destination allowlists/controlled adapters, safe DNS/IP handling, redirect limits, egress controls, timeouts, and response-size limits.
- File/path/archive/image/document parsers run with least privilege, strict bounds, patched libraries, timeouts, and quarantine; archive traversal and decompression bombs are explicitly tested.
- Unhandled errors fail safely, roll back effects where applicable, and expose no stack, SQL, filesystem, network, vendor, or secret detail.

### Authentication and authorization

- Provider/credential/session choice is gated by OD-005 and a future ADR; use current vetted standards and libraries, never custom cryptography.
- Enforce deny-by-default, per-request, resource/context-aware backend policy and the [permission matrix](permission-matrix.md).
- Privileged sessions are separate, short-lived, step-up capable, revocable, and protected by narrow roles and separation of duties.
- Recovery, linking, identity changes, provider verification, and role grants resist enumeration, takeover, social engineering, self-approval, and stale-session privilege.
- Authorization decisions fail closed; caches do not authorize high-risk state independently.

### Cryptography, keys, and secrets

- TLS protects all shared-environment data in transit. Service/database/cache/object connections authenticate peers and use approved encryption.
- Data at rest uses provider/platform encryption plus application-level protection only when the threat/requirements justify it.
- Cryptographic algorithms, key sizes, modes, password hashing, token signing, and random generation use current vetted libraries/configuration selected during implementation review.
- Keys and secrets are generated from approved entropy, uniquely scoped by environment/service/purpose, stored in a secret/key manager, access-controlled, rotated, revocable, auditable, and excluded from Git/build artifacts/logs.
- No shared production secret across unrelated services or environments. Prefer workload identity and short-lived credentials.
- Rotation supports overlapping verification where needed, explicit key IDs, rollback/recovery, compromised-key revocation, and re-encryption/re-signing plans.
- Encryption does not replace authorization, minimization, deletion, integrity validation, or secure endpoints.

### Data stores and files

- PostgreSQL is authoritative; Redis data is disposable; object storage is private and metadata-authorized as defined by [data architecture](../architecture/data-architecture.md).
- Runtime and migration database roles are separate and least-privileged. Manual production access is time-bound, audited, and incident/support justified.
- KYC/media/evidence uploads use random object IDs, direct authorization, quarantine, content/type/size/digest checks, malware scanning, safe serving, lifecycle, and deletion verification.
- Signed URLs are short-lived bearer capabilities, never long-term authorization, and are excluded from logs/referrers where possible.
- Backups, replicas, exports, and restore environments receive production-equivalent restricted-data protection and tested access/deletion behavior.

### External providers and integrations

- Each provider requires security/privacy/legal/availability/cost review, data-flow inventory, least-privilege credentials, contract/terms, incident contacts, retention/deletion, subprocessor/residency, and exit strategy.
- Send only required fields. Provider SDK/request types stay behind adapters and do not become domain contracts.
- Outbound calls use allowlisted endpoints, TLS validation, timeouts, bounded retry, circuit/load protection, response-size/schema validation, idempotency, and safe error mapping.
- Webhooks verify signature/authenticity using raw signed bytes as required, validate time/replay/nonce where supported, enforce size/schema, process idempotently, and do not trust event order.
- Provider dashboards, support channels, and logs must not become alternate uncontrolled access paths.
- Provider outage or compromise has a documented fallback/disable path; AI assistance never blocks an approved manual core flow by default.

### Payments

- Use the approved payment provider's hosted/tokenized capabilities to minimize regulated payment data; never trust client success.
- Verify signatures and amount/currency/booking/merchant context server-side, protect replay, process idempotently, and reconcile with immutable internal records.
- Refunds/adjustments enforce state, ownership, limits, reason, separation of duties, and independent approval above approved thresholds.
- Financial identifiers and provider payloads are restricted, minimized in telemetry, and retained only under approved financial/legal policy.
- Payment-provider selection, PCI responsibility, taxes, payouts, and refund policy remain OD-008/OD-009 gates.

### Location and real-time

- Location collection is lifecycle- and purpose-bound, consent/lawful-basis gated, precision-limited, rate-limited, freshness-marked, and retained minimally.
- Customers see provider location only for an authorized active relationship/state; providers receive only location required for the accepted work.
- Presence/location inputs validate actor, sequence/time, plausibility bounds, rate, and booking/provider state; spoofing signals do not automatically punish without review.
- Realtime channels authenticate, authorize each subscription/event, isolate users/bookings/environments, bound message size/rate, and reconcile after gaps.
- Stale/offline/unknown location and ETA are displayed honestly; no false freshness or guaranteed arrival.

### AI

- Treat prompts, user content, retrieved data, tool inputs, model output, and provider responses as untrusted.
- Minimize/redact inputs, prohibit unapproved provider training/retention, separate environments, and exclude secrets, raw KYC, unrestricted complaints, payment credentials, or unnecessary precise location.
- Defend against prompt/content injection by separating instructions/data, allowlisting tools/actions, validating structured output, enforcing authorization outside the model, and requiring explicit confirmation/human review for consequential use.
- Model output cannot approve providers, authorize access, create/accept bookings, settle/refund payment, expose restricted data, enforce fraud actions, or send emergency dispatch without deterministic validated policy.
- Evaluations cover privacy leakage, harmful content, prompt injection, hallucination/abstention, bias, quality, latency, cost, and fallback before release.
- AI provider, data governance, evaluation thresholds, supported languages/features, and human-review policy remain FN-016/OD-015 gates.

### Administration and support

- Admin functionality uses separate privileged authentication context, narrow roles, minimized projections, reason/case requirements, step-up/dual control, and audit.
- User impersonation is prohibited by baseline. Support diagnostics use explicit read projections or controlled “view as” rendering without obtaining a user's session/credentials or executing writes as that user.
- Bulk search/export is separate permission with bounds, purpose, approval, encryption, expiry/deletion, and anomaly monitoring.
- Sensitive evidence access is assignment- and purpose-bound; browsing unrelated KYC, complaints, location, emergency, or payments is prohibited.
- Break-glass is disabled for routine use, time-bound, strongly authenticated, independently notified, fully audited, and reviewed immediately after use.

### Infrastructure, CI/CD, and supply chain

- Cloud/IaC provider, deployment topology, and CI platform remain future decisions, but least privilege, environment isolation, review, policy-as-code validation, and auditable deployment are required.
- Protect branches/tags/releases; pin toolchains/actions/images/dependencies to reviewed immutable versions or digests where supported.
- Generate dependency inventory/SBOM, scan known vulnerabilities and licenses, verify provenance/signatures where supported, and define risk-based remediation timelines.
- Build workers receive minimum short-lived secrets and no unnecessary production network/data access. Pull-request code from untrusted contexts cannot access protected secrets.
- Artifacts are reproducible where practical, integrity-addressed/signed, scanned, promoted rather than rebuilt per environment, and traceable to reviewed source.
- Production deployment requires approved checks, separation of duties proportional to risk, health verification, rollback, and change/audit evidence.
- No public datastore, admin interface, debug endpoint, default credential, permissive security group, or wildcard cloud role.

## Abuse and fraud controls

Abuse defenses supplement authentication/authorization and MUST avoid hidden discriminatory outcomes.

- Threats include account creation/takeover, OTP/recovery abuse, enumeration, scraping, request spam, provider collusion, fake availability/location, booking acceptance races, cancellation abuse, payment/refund abuse, review manipulation, complaint harassment, document fraud, admin insider misuse, and emergency misuse.
- Controls MAY combine per-account/device/network/operation rate limits, verified state, velocity, idempotency, quotas, friction, anomaly signals, manual review, and temporary containment.
- IP/device identifiers are signals, not identity. Shared networks, accessibility, device changes, and legitimate high-volume users require false-positive analysis and appeal/recovery.
- Enforcement has stable reasons, evidence, proportional action, review/appeal, audit, retention, and policy version.
- AI/fraud signals cannot autonomously impose consequential penalties without approved deterministic policy and human review where required.
- Rate-limit and fraud thresholds are sensitive configuration, not public API promises; owners and validation plans are required before production.

## Logging, monitoring, and audit

### Never log

- Passwords, OTPs, session/access/refresh tokens, cookies, private keys, secret values, payment signatures, or complete authorization headers.
- Raw KYC, complaint evidence, uploaded media, precise coordinates/routes, full payment/provider payloads, AI prompts/outputs containing personal data, or signed object URLs.
- Full request/response bodies by default, SQL parameters, Redis values, or data exports.

### Required telemetry design

- Use structured bounded event schemas, approved severity, UTC time, environment/service, correlation/trace reference, safe event/result code, latency, and opaque actor/resource references where necessary.
- Redaction happens before serialization/export; downstream masking is not the primary protection.
- Access to logs/audit/metrics/traces follows classification, least privilege, retention, and environment boundaries.
- Alert on account/role anomalies, repeated denied/high-risk actions, secret/key events, unusual exports/evidence access, payment reconciliation issues, provider callback failures, malware/scanning backlog, storage public-access drift, and control degradation.
- Security audit evidence is integrity-protected and cannot be modified through application roles.
- Detection rules have owner, purpose, data fields, false-positive plan, response runbook, test method, and review interval.

## Secure development lifecycle

### Design

- Classify data and update the [threat model](threat-model.md) before implementing a new trust boundary, data class, external provider, privileged action, payment/location/emergency flow, file parser, or AI tool.
- Record hard-to-reverse choices as ADRs and identify misuse/abuse cases, safe failure, recovery, monitoring, and deletion.
- High-risk designs require security/privacy review before code, not only before release.

### Build and review

- Use maintained vetted libraries and pinned toolchains; no custom cryptography or copied unknown scripts.
- Reviews trace untrusted input to validation/encoding, authorization, domain invariants, storage, logs, external calls, and output.
- Security-sensitive changes require reviewers with the relevant expertise and focused tests.
- Secrets and real personal data are prohibited in source, fixtures, examples, issue/PR text, generated artifacts, and logs.

### Verify

- Unit tests cover validation, encoding, policy, state transitions, redaction, and safe failures.
- Integration tests cover authorization, concurrency, database constraints, idempotency, webhooks, cache loss, object access/scanning/deletion, and external failures.
- E2E tests cover critical customer/provider/admin journeys and negative cross-role/cross-user cases.
- Automated checks include type/lint/test, dependency/license audit, secret scan, static analysis, IaC/container/mobile/web security checks, and contract compatibility once toolchains exist.
- Manual/adversarial review targets authentication/recovery, access control, business logic, payments, KYC/files, location/realtime, admin/export, emergency, AI, and infrastructure.
- No tool result alone proves security; findings are risk-triaged, remediated, retested, and tracked.

## Security and privacy incident response

### Incident classes

- Credential/secret exposure or account takeover.
- Unauthorized data access, export, alteration, or deletion.
- KYC, location, payment, complaint, emergency, media, or AI privacy event.
- Malicious upload/parser compromise, dependency/supply-chain compromise, or infrastructure exposure.
- Payment fraud/reconciliation integrity failure, authorization bypass, admin misuse, or emergency-system abuse.
- Ransomware/data loss, backup failure, or material control/monitoring outage.

### Response lifecycle

1. **Report and triage:** Use the private process in `SECURITY.md`; preserve minimum evidence, classify potential impact, appoint incident/security and privacy/legal leads.
2. **Contain:** Revoke/rotate affected credentials and sessions, disable narrow features/integrations, isolate resources, block abusive paths, and preserve evidence without destroying needed data.
3. **Assess:** Identify affected systems, actors, data classes/subjects, time window, actions, vendors/regions, integrity/availability impact, and continuing risk.
4. **Eradicate and recover:** Fix root cause, rebuild/restore from verified sources, validate authorization/data integrity, monitor recurrence, and use staged re-enable/rollback.
5. **Notify and coordinate:** Privacy/legal determines regulator/user/provider/law-enforcement/insurer/partner obligations and timelines; no invented notification promise substitutes for jurisdiction review.
6. **Learn:** Complete blameless post-incident analysis, update threat model/runbooks/tests/controls, assign tracked remediation, and verify completion.

- Do not delete or rewrite shared history as an ad hoc secret response. Rotate/revoke first, preserve evidence, then use an approved history-cleaning process when required.
- Incident tools and channels must be pre-authorized and protected; public issues never contain vulnerability or customer details.
- At least tabletop exercises for account takeover, leaked secret, data export, payment webhook compromise, location exposure, malicious upload, and vendor breach are required before production.

## Verification and release gates

| Gate | Required evidence | Accountable owners |
| --- | --- | --- |
| New data processing | Inventory entry, purpose/necessity, classification, lawful-basis/consent review, notice, access, retention/deletion, vendor/rights impact | Product, privacy/legal, domain engineering, security |
| Authentication/recovery | Threat model, provider ADR, assurance/recovery policy, enumeration/takeover/abuse tests, session/revocation controls | Identity engineering, security, product, privacy/legal |
| KYC/provider verification | Jurisdiction/category requirements, document minimization, private storage/scanning, reviewer matrix, retention/deletion, appeal, vendor review | Trust/operations, privacy/legal, security |
| Payment/refund | Provider/compliance ADR, server verification, idempotency/reconciliation, monetary/separation controls, data scope, incident/rollback tests | Finance, payments engineering, security, privacy/legal |
| Precise location/realtime | Purpose/state/precision/retention, consent/fallback, channel authorization, spoof/stale/offline tests, disclosure review | Product/location, privacy/legal, security |
| Emergency | Legal/safety scope, public-service guidance, provider qualification, dispatch/fallback/abuse policy, enhanced audit, tabletop | Safety/product, operations, legal/privacy, security |
| AI | Governance/provider ADR, data minimization/terms, injection/output/tool controls, evaluations, human review, fallback, cost/incident plan | AI, product, privacy/legal, security |
| Admin/export | Permission matrix, separate privileged session, step-up/dual control, bounded projections, anomaly detection, audit, break-glass test | Operations, security, privacy/legal, auditor |
| Production release | Threat/risk review, passing required tests/scans, no unresolved release blockers, monitoring/runbooks, backup/restore, rollback, approved residual risk | Engineering, operations, security, privacy/legal, product |

## Open decisions that block affected production capabilities

- OD-001/OD-003: launch jurisdiction and marketplace/provider legal model.
- OD-005/OD-006: identity assurance, authentication/recovery, and KYC requirements.
- OD-008/OD-009: price/payment/refund/payout/compliance model.
- OD-011/OD-012: emergency and notification scope/providers/policy. OD-010 provider live-location policy is approved in the product requirements and ADR-0012; each implementation still requires the focused precise-location release review above.
- OD-013/OD-014: complaints, enforcement, appeals, ratings, and moderation policy.
- OD-015: AI features/providers/data governance/evaluation thresholds.
- OD-016/OD-020: retention, deletion, legal hold, suspension/offboarding, and active-work handling.
- OD-017/OD-018: availability/recovery/scale/support objectives and cloud/region/budget ownership.
- Named privacy/legal and security owners, applicable regulatory obligations, and risk-acceptance authority.

## Primary references

- [OWASP Application Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/)
- [OWASP Mobile Application Security Verification Standard](https://mas.owasp.org/MASVS/)
- [OWASP Threat Modeling Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html)
- [NIST Secure Software Development Framework SP 800-218](https://csrc.nist.gov/pubs/sp/800/218/final)
- [NIST Privacy Framework](https://www.nist.gov/privacy-framework)

These sources establish control and review baselines. Applicable law, contracts, approved product policy, and project-specific risk decisions remain authoritative for FixNow.
