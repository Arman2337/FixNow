# Threat model and risk register

## Model status

- Status: Initial architecture baseline
- Date: 2026-08-09
- Method: Asset/data-flow review with STRIDE-style security threats plus privacy, abuse, safety, and operational misuse cases
- Scope: Planned FixNow mobile, backend, admin, data stores, external providers, AI, and operations boundaries
- Evidence status: Design controls only; implementation verification remains pending in the owning tasks

This model must be updated when a task adds or materially changes a trust boundary, sensitive data class, external provider, privileged action, payment/location/emergency flow, file parser, AI capability, or deployment topology.

## Risk scale

| Rating | Meaning | Release handling |
| --- | --- | --- |
| Critical | Plausible catastrophic safety, broad restricted-data, systemic authorization, financial integrity, secret/control-plane, or unrecoverable impact | Must be prevented or reduced before release; residual acceptance requires executive/product, security, privacy/legal, and relevant domain owner |
| High | Serious account/data/financial/safety impact or scalable abuse with limited containment | Must have implemented tested controls and accountable residual-risk acceptance before affected release |
| Medium | Material but bounded impact or lower-likelihood path requiring meaningful access/conditions | Track owner and validate controls before affected capability reaches production |
| Low | Limited impact and exploitability with straightforward containment | Track in normal hardening and monitor assumptions |

Ratings are preliminary until launch scope, jurisdiction, scale, providers, and operational targets are known. A lower rating cannot be inferred merely because the product is not yet implemented.

## Assets

- Human/service identities, credentials, sessions, recovery evidence, role/policy state, and privileged access.
- Customer/provider profiles, KYC/qualification documents, precise location, contact and service details.
- Service requests, bookings, assignment/lifecycle state, availability, matching rules, and history.
- Payment orders, signatures, transactions, refunds, invoices, provider earnings, and reconciliation state.
- Ratings, complaints, evidence, enforcement, appeals, fraud signals, emergency data, and audit history.
- Uploaded media, AI prompts/outputs/evaluation data, notification/device tokens, and provider callbacks.
- Source, dependencies, CI/CD, artifacts, secrets/keys, infrastructure control plane, data stores, backups, logs, and monitoring.
- Product availability, user trust, provider safety, financial accuracy, privacy rights, and incident evidence.

## Adversaries and failure actors

- Anonymous attacker, bot, scraper, spammer, extortionist, or fraud ring.
- Malicious/compromised customer, provider applicant, verified provider, administrator, reviewer, support, finance, or service identity.
- Abusive party in a booking/complaint or person with physical access to a device.
- Compromised dependency, CI runner, developer workstation, cloud/provider account, SDK, container, artifact, webhook, or AI provider.
- Curious/overprivileged insider or support/vendor employee.
- Accidental actor: developer, operator, reviewer, user, migration, retry, race, misconfiguration, stale cache, failed backup, or unreliable network/provider.
- Model/prompt/content attacker influencing AI interpretation, tool calls, or data disclosure.

## Trust-boundary inventory

| Boundary | Untrusted inputs | Critical enforcement |
| --- | --- | --- |
| Mobile/browser → edge/API | Parameters, bodies, files, headers, tokens, deep-link state, origin | TLS, size/rate limits, protocol/schema validation, authentication, CSRF/origin controls where applicable |
| Edge/API → backend domain | Principal/context, normalized request, gateway metadata | Internal identity mapping, centralized authorization, domain invariants, idempotency, safe correlation |
| Backend → PostgreSQL/Redis/object storage | Queries, keys, objects, metadata, migrations | Parameterization, least privilege, constraints, cache non-authority, private storage, quarantine, encryption, lifecycle |
| Backend → external providers | Requests, credentials, personal data; provider responses/callbacks | Minimization, adapters, egress allowlist, TLS, timeout, response/schema/signature/replay checks, reconciliation |
| Backend/AI → model provider | Prompts/content, retrieved context, model output/tool proposals | Data governance, injection isolation, output schema, deterministic auth, human confirmation, no direct authority |
| Admin/support → privileged API | High-impact requests, search/export, evidence access | Separate session, narrow role, purpose/case, step-up/dual control, audit/anomaly detection |
| CI/CD/operations → runtime/data | Source, dependencies, artifacts, IaC, secrets, deploy/admin actions | Protected review, pinned provenance, isolated short-lived identity, least privilege, audit, rollback/break-glass |
| Backup/restore/export → alternate environment | Full sensitive datasets, tombstones, keys, access policy | Encryption, strict access, isolated restore, current auth/deletion replay, expiry/destruction verification |

## Threat register

Each owner below is a role, not an assertion that a person is already assigned. “Release gate” means the affected capability cannot ship until evidence exists.

| ID | Threat and impact | Initial risk | Required controls | Owner | Validation evidence | Release gate/residual risk |
| --- | --- | --- | --- | --- | --- | --- |
| TH-001 | Credential stuffing, OTP/recovery abuse, enumeration, or account takeover exposes accounts/bookings/location/payments | High | Generic responses, abuse limits, verified recovery, secure sessions, MFA/step-up policy, revocation, anomaly detection | Identity + Security | Auth/recovery abuse tests, session theft/revocation tests, alert exercise | Identity launch; residual fraud risk reviewed |
| TH-002 | Role/ownership/IDOR bypass exposes or mutates another user's/provider's/admin resource | Critical | Deny-by-default hybrid policy, opaque IDs, per-request resource checks, field projections, fail closed | Domain Eng + Security | Permission-matrix tests, identifier tampering, missing-policy/dependency tests | Every protected endpoint; no open bypass |
| TH-003 | Privileged role self-grant, stale grant, broad admin, or insider browsing restricted data | Critical | Narrow roles, separate admin identity/context, dual approval, expiry/recertification, purpose/case, anomaly/audit | Security + Operations + Auditor | Grant conflict/expiry/revocation tests, access review, insider-use alert drill | Admin release; break-glass tested |
| TH-004 | Injection, unsafe deserialization, XSS/CSRF, path/archive traversal, SSRF, or parser exploit compromises data/runtime | Critical | Boundary schemas, parameterization/encoding, safe parsers, egress controls, browser defenses, sandbox/limits, patched libraries | Engineering + Security | SAST/dependency checks, malicious input/file/SSRF/browser tests, manual review | Public/admin endpoints and uploads |
| TH-005 | Malicious KYC/media/evidence file spreads malware, leaks metadata, executes active content, or creates decompression/processing DoS | High | Private quarantine, type/size/digest detection, metadata stripping, malware/content scan, safe serving, bounded parser | Storage Eng + Security + Trust | EICAR-equivalent safe test, polyglot/mismatch/bomb/traversal tests, scan outage/backlog drill | Any upload feature |
| TH-006 | Precise location is collected, retained, inferred, spoofed, or disclosed outside an active purpose | Critical | Purpose/state/consent, minimum precision/TTL, authorized channels, stale marking, spoof review, no raw telemetry | Location Eng + Privacy + Security | Cross-user/state tests, revoke/expiry/offline/spoof tests, inventory/retention verification | Location/realtime/emergency launch |
| TH-007 | Booking acceptance/lifecycle race, replay, retry, or stale state creates double assignment or unauthorized progress | High | DB constraints/transactions, idempotency, optimistic concurrency, legal transitions, reconciliation | Booking Eng | Concurrent acceptance, retry/replay, stale-version, rollback tests | Booking launch |
| TH-008 | Payment callback forgery/replay, amount mismatch, duplicate charge/refund, or ledger alteration causes loss | Critical | Provider signature/auth, raw-byte verification, idempotency, amount/currency/booking checks, immutable records, reconciliation, dual limits | Payments + Finance + Security | Sandbox/adversarial webhook, race/replay, reconciliation/refund approval tests | Payment launch; compliance approval |
| TH-009 | Redis stale/poisoned/lost state authorizes action, leaks data, bypasses limits, or overloads PostgreSQL on fallback | High | Redis non-authority, safe namespaces/TTL, authoritative checks, cache-aside invalidation, bounded fallback/stampede control | Backend + Operations | Eviction/loss/stale/poison/outage/load tests | Any Redis-backed critical path |
| TH-010 | Object URL/public ACL/key leakage or metadata/object drift exposes KYC/media/evidence/exports | Critical | Public-access prevention, private random keys, short scoped URLs, DB auth metadata, encryption, reconciliation, audit | Storage + Security + Privacy | ACL/config scan, expired/cross-user URL tests, orphan/delete/restore reconciliation | Restricted object feature |
| TH-011 | Logs, metrics, traces, support tools, errors, screenshots, or analytics become an uncontrolled sensitive-data copy | High | Data-minimized schemas, pre-export redaction, access/retention, no bodies/secrets/location/evidence, safe errors | Engineering + Operations + Privacy | Log fixture/sink inspection, redaction tests, access/retention review | Every service; focused restricted-data gate |
| TH-012 | Secret/key exposure in Git, build, client, CI logs, image, environment, or provider dashboard enables compromise | Critical | Secret manager, short-lived workload identity, scopes, scans, rotation/revocation, protected CI, no client secrets | Platform + Security | Secret scans, canary/rotation exercise, artifact/image/log inspection, IAM review | CI/runtime release; rotate first on exposure |
| TH-013 | Dependency, SDK, action, container, package, developer or CI compromise injects malicious artifacts | Critical | Review/pinning, provenance/signing, SBOM, isolated builds, minimal secrets/network, scanning, protected promotion | Platform + Security | Dependency/provenance/SBOM checks, compromised-runner tabletop, artifact verification | Build/deploy pipeline |
| TH-014 | Cloud/network/IaC misconfiguration exposes datastore, admin/debug endpoint, bucket, backups, or excessive role | Critical | Reviewed IaC, deny public defaults, least privilege, segmentation, drift/policy checks, environment isolation | Platform + Security | IaC/security tests, external exposure scan, IAM graph/review, drift alert drill | Staging/production provisioning |
| TH-015 | AI prompt/content injection leaks data, bypasses policy, invokes tools, produces unsafe booking/price/fraud/emergency action | Critical | Input minimization, instruction/data separation, no model auth, allowlisted tools, output schema, deterministic policy, confirmation/human review, fallback | AI + Security + Product | Injection/data-exfil/tool-abuse evaluations, output/fallback/human-review tests | Each AI feature; governance/provider approved |
| TH-016 | Notification/device token misuse or lock-screen content exposes booking, location, complaint, payment, or emergency data | High | Token ownership/lifecycle, minimum templates, preference/consent, no sensitive default content, provider access limits | Notifications + Privacy | Cross-user token, invalid/revoked token, template/privacy, retry tests | Notification launch |
| TH-017 | Complaint/review/enforcement abuse enables harassment, retaliation, evidence leakage, biased punishment, or metric manipulation | High | Eligibility, reporter protection, assigned evidence access, moderation, reasons, proportional policy, appeal, human review, versioned metrics | Trust + Privacy + Security | Cross-party access, conflict/appeal, false-positive, audit/retention tests | Ratings/complaints/trust launch |
| TH-018 | Emergency feature creates false assurance, abusive priority, unsafe provider dispatch, or restricted-data exposure | Critical | Legal/safety scope, clear limits/public guidance, deliberate confirmation, qualified eligibility, abuse control, no-match fallback, enhanced audit | Safety/Product + Operations + Legal + Security | Scenario/tabletop, abuse/no-provider/offline/location/access tests, wording approval | Emergency launch; no unresolved legal/safety gate |
| TH-019 | Backup/restore failure, ransomware, deletion error, or destructive migration causes loss or resurrects deleted/revoked data | Critical | Encrypted PITR/version controls, immutable/offline strategy as approved, restore drills, tombstone/current-auth replay, staged migrations, exact approvals | Data + Operations + Security + Privacy | Restore/RPO/RTO, corruption/ransomware tabletop, deletion-after-restore, migration recovery tests | Production data and destructive change |
| TH-020 | Vendor outage/breach/retention/subprocessor change leaks data or breaks critical flows | High | Due diligence/DPA/terms, minimization, scoped credentials, monitoring, incident contacts, fallback/disable, deletion/export, exit plan | Vendor Owner + Security + Privacy + Operations | Contract/control review, outage/breach tabletop, credential revoke, data deletion evidence | Each external provider |
| TH-021 | Rate-limit, fraud, or device/network signals discriminate, lock out legitimate users, or are evaded at scale | High | Multi-signal bounded controls, accessibility/shared-network review, reason/appeal, human review, monitoring, sensitive thresholds | Trust + Product + Security | Load/evasion/false-positive/cohort/accessibility tests, appeal drill | Abuse control deployment |
| TH-022 | Excessive collection, invalid consent, purpose creep, indefinite retention, or failed rights/deletion violates privacy | Critical | Inventory/DPIA-style review, lawful basis/consent, minimization, purpose controls, retention/deletion, vendor propagation, rights process | Privacy/Legal + Product + Eng | Inventory audit, consent/withdrawal, export/correction/delete/legal-hold, restored-data tests | Any real personal-data processing |
| TH-023 | Cross-environment or tenant-like scope mix exposes production data/credentials to dev/test or another user/service | Critical | Separate accounts/projects/credentials/data, audience/environment claims, namespace/container isolation, no prod fixtures, egress/access controls | Platform + Engineering + Security | Cross-environment token/data tests, config/IAM review, synthetic fixture scan | Every shared environment |
| TH-024 | Audit evidence is missing, altered, overexposed, or too sensitive to support investigation/accountability | High | Structured minimal events, integrity/access, independent auditor, retention, clock/correlation, no application mutation | Security + Auditor + Privacy | Event coverage, tamper/access tests, incident reconstruction exercise, retention review | Privileged/high-risk capabilities |
| TH-025 | Denial of service through expensive search/matching, uploads, realtime, AI, provider retries, or database exhaustion blocks core flows | High | Size/rate/time/cost bounds, pagination, queues/backpressure where approved, circuit/load shedding, quotas, capacity/alerts, safe degradation | Domain Eng + Operations + Security | Load/soak/abuse tests, dependency failure, cost-budget, recovery drills | Public/high-cost capabilities |
| TH-026 | Mobile/browser local compromise exposes cached data/session or triggers malicious deep link/intent | High | Minimum local data, protected storage, clear on revoke, deep-link validation, safe screenshots/clipboard/backups, CSP/browser defenses | Mobile/Admin Eng + Security + Privacy | Device backup/log inspection, deep-link/intent, XSS/CSRF, session theft/revoke tests | Mobile/admin launch |
| TH-027 | Unbounded support/admin search or export enables mass scraping/exfiltration without a single authorization bypass | Critical | Separate list/export permissions, bounded filters/results, purpose/approval, encryption/expiry, anomaly detection, audit | Operations + Security + Privacy | Bulk/slow enumeration tests, export approval/expiry, anomaly alert drill | Admin search/export |
| TH-028 | Security control outage or fail-open fallback disables auth, scanning, policy, secrets, audit, or monitoring silently | Critical | Fail closed for protected actions, explicit degraded state, health/alerts, narrow feature disable, tested recovery, no bypass flag | Platform + Security + Domain Eng | Dependency/control outage and recovery tests, alert/runbook/tabletop | Each critical control dependency |

## Privacy-risk questions

Every data-flow review answers:

1. Can the purpose be met without personal data or with less/coarser/shorter-lived data?
2. Does the user reasonably expect this collection, inference, sharing, automation, retention, and administrator access?
3. Could the data reveal home/work/routine, identity documents, finances, disputes, safety status, relationships, or vulnerable circumstances?
4. Can denial of consent/permission use a manual fallback without coercion or material dark-pattern pressure?
5. Who receives data, in which regions, under what terms, for how long, and for their own training/analytics?
6. What derived data, logs, caches, backups, exports, model outputs, and fraud signals persist after the source is deleted?
7. How can a person access, correct, contest, export, restrict, or delete data without exposing another person or weakening abuse/security controls?
8. Could an apparently aggregated/pseudonymous value be re-identified or used to discriminate?
9. What happens after account suspension/offboarding, booking completion/cancellation, complaint appeal, provider rejection, or emergency closure?
10. What evidence proves the promised behavior in production and after restore/vendor deletion?

## Threat-model review triggers

Update and re-review this model when:

- A task adds a new actor/role, permission, admin action, data class, external provider, SDK, public endpoint, file/media type, AI tool/model, notification channel, realtime event, or environment.
- A contract changes ownership, lifecycle, visibility, purpose, precision, retention, legal basis, payment amount flow, or emergency behavior.
- A dependency/provider/license/hosting model materially changes.
- A vulnerability, incident, abuse pattern, audit finding, test failure, or production metric invalidates an assumption.
- Launch geography, scale, availability, support, or legal obligations become known.

The reviewer records changed data flows/threats, control owner, validation evidence, residual rating, decision/ADR links, and required tracker tasks. Discovered implementation work is tracked separately and is not silently bundled into the reviewing task.
