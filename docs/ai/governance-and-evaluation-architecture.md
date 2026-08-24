# AI governance and evaluation architecture

## Status, scope, and authority

This is FixNow's normative design for planned AI assistance. It implements the governance gate in product requirement `OD-015` and refines the AI controls in the [security and privacy architecture](../security/security-and-privacy-architecture.md). It is not an implementation, a provider approval, an authorization to transmit customer data, or evidence that a model is available.

It governs these planned capabilities:

1. Interpret a customer-written issue description.
2. Recommend one existing active FixNow service category.
3. Ask one useful clarification question for an ambiguous description.
4. Later, transcribe or translate voluntarily supplied voice.
5. Later, analyze a voluntarily supplied issue image.

This policy excludes payment, pricing, invoices, refunds, wallet, payouts, ratings, reviews, review moderation, provider assignment, booking creation, emergency dispatch, identity/KYC assessment, fraud enforcement, diagnosis, and legal, medical, or emergency-response advice.

## Product and decision boundaries

### Approved uses

| Capability | Allowed advisory outcome | Required user control |
| --- | --- | --- |
| Issue text | Plain-language restatement or bounded service context | Customer can edit, ignore, or continue manually. |
| Category recommendation | One validated active catalog category, with uncertainty disclosed | Customer must select or change the category before creating a request. |
| Clarification | One neutral question when the input lacks enough context | Customer may answer, skip, or browse categories. |
| Voice later | Transcription/translation of a customer-selected recording | Explicit recording and AI-processing notice; editable transcript. |
| Image later | Non-diagnostic issue context from a customer-selected image | Explicit image/AI-processing notice; customer reviews result. |

### Prohibited uses and hard invariants

- AI never creates, modifies, submits, accepts, cancels, or completes a booking.
- AI never assigns, ranks for assignment, contacts, or discloses a provider.
- AI never dispatches emergency services or represents itself as an emergency-response authority.
- AI never creates a service category, maps to an inactive category, or replaces the authoritative service catalog.
- AI never determines a price, payment, refund, payout, rating, review, eligibility, KYC result, fraud action, or legal outcome.
- AI never receives secrets, authentication material, payment data, exact location, contacts, private provider/customer information, or domain write credentials.
- AI output is never fact, diagnosis, policy, or authorization. It is clearly labelled as an optional suggestion with an uncertainty-aware fallback.

Violating any hard invariant is a release blocker. A deterministic backend policy, not a model, owns all domain actions.

## Architecture and provider abstraction

```text
Customer client
  -> authenticated, versioned backend advisory endpoint
  -> input minimizer + safety pre-screen + rate/budget gate
  -> active service-catalog snapshot builder
  -> provider-neutral AI advisory port
  -> provider adapter (no domain tools, no write authority)
  -> parse/schema validator + catalog-grounding validator
  -> safety/abstention policy + redacted audit/metrics
  -> advisory response for customer confirmation or manual fallback
```

The future `ai/` domain owns provider-neutral interfaces, prompt templates, evaluation assets with no sensitive production data, policy tests, and adapters. `backend/` owns authentication, authorization, category lookup, domain invariants, API contracts, configuration validation, redaction, and audit. Clients display only a backend-approved advisory result and retain the ordinary manual flow. Applications must not import another application's private source.

The provider port accepts a bounded, purpose-specific request and returns a bounded structured candidate. It has no general browsing, plug-ins, function calling, database connection, URL retrieval, messaging, map, payment, identity, booking, provider, or emergency tools. The model and provider response are untrusted inputs. The port must support provider/model version identification, timeout/cancellation, idempotent correlation, token/usage reporting, and a disabled adapter for local/default tests.

No provider is selected by FN-016. A provider can be considered only after product, AI, privacy/legal, security, and operations approve: purpose limitation; a signed data-processing agreement; no training on FixNow content; no retention by default; deletion and subprocessor commitments; approved residency/transfer terms; encryption and access controls; incident notification and audit rights; schema/structured-output support; documented latency, availability, quotas, cost, and exit path; and evidence of security, privacy, safety, and model-quality review.

## Data classification and privacy boundaries

| Class | Examples | AI handling rule |
| --- | --- | --- |
| Public | Published active service-category names, neutral descriptions, icons | May form a versioned catalog snapshot. Do not expose unpublished/admin-only metadata. |
| Internal | Prompt template version, safety taxonomy, aggregate evaluation metrics | Backend-only. Do not reveal system prompts, detection rules, or operational thresholds to customers. |
| Confidential | Customer-supplied issue text after minimization, selected locale/language | Allowed only for the explicit advisory purpose and only after the provider gate is approved. Do not send account identity or booking context. |
| Restricted | Names, email/phone, address, exact/coarse coordinates, routes, account/session IDs, payment data, OTPs, KYC, complaints, provider qualifications, private messages, raw audio/images, EXIF, credentials | Prohibited from model prompts and provider telemetry unless a later capability has separate documented approval and explicit user notice/consent. |

Allowed customer data for the initial text feature is limited to: the text the customer voluntarily enters for classification, a customer-selected language/locale when necessary, and the current active-catalog snapshot. The backend removes or rejects identifiers, contact information, addresses, links, secrets, payment terms, and other restricted fields before any provider boundary. The initial request does not include user ID, booking ID, device ID, service address, provider identity, chat history, account history, or location.

### Location and image rules

- **Location:** do not include precise location, address, route, live location, reverse-geocoded place, or location-derived profile data in an AI request. Category recommendation does not need location. Any future location use requires a separate purpose, minimization/precision decision, privacy/legal approval, consent disclosure, retention plan, and focused security review.
- **Images:** issue-image analysis is later scope. It requires explicit, separate notice and affirmative customer action; MIME/size validation; malware scanning/quarantine; metadata and EXIF stripping before analysis; least-privilege private storage; bystander/face/identity safeguards; a documented deletion schedule; and a provider-specific data-processing approval. Do not use images for identity, KYC, surveillance, diagnosis, or emergency dispatch. Do not use production images as evaluation data without documented consent and approval.
- **Voice:** voice transcription/translation is later scope and requires explicit recording/processing notice, editable output, language support evaluation, minimization, and the same restricted-media provider and retention gates.

Raw prompts, raw model outputs, audio, images, and transcripts are not retained by default for AI telemetry or evaluation. A proposed retention period, legal basis, data-subject handling, deletion workflow, provider retention setting, and named privacy/legal owner are required before persistence or external transmission. The policy is deny-by-default rather than an assumed duration.

## Structured advisory response and validation

The future backend contract should use a discriminated result rather than expose unvalidated provider fields. Names are server-derived after catalog validation.

```ts
type AdvisoryOutcome =
  | {
      kind: 'recommendation';
      recommendedServiceCategoryId: string;
      recommendedServiceName: string; // derived from validated active catalog
      confidence: number; // 0 through 1
      shortReason: string;
      safetyNotice?: SafetyNotice;
    }
  | {
      kind: 'clarification';
      clarificationQuestion: string;
      safetyNotice?: SafetyNotice;
    }
  | {
      kind: 'abstention';
      shortReason: string;
      safetyNotice?: SafetyNotice;
    };

type SafetyNotice =
  | 'gas_smell'
  | 'exposed_electrical_wiring'
  | 'fire'
  | 'flooding'
  | 'dangerous_structural_damage';
```

The provider can return only an enum outcome, a catalog ID candidate, bounded text, confidence, and a safety signal. The backend must reject unknown keys, invalid enum values, out-of-range confidence, unexpected markup/links, oversized text, missing required fields, and any output that violates the active-catalog snapshot. It must derive `recommendedServiceName` from the authoritative snapshot after confirming `isActive === true`; it must never display a model-provided category name. A stale snapshot, catalog lookup error, disabled category, schema failure, or provider failure becomes a clarification, abstention, or manual category browser.

An approved recommendation needs a configured offline threshold. The initial policy target is `confidence >= 0.85`, valid active-category grounding, no active safety signal, and no ambiguity rule hit. Scores below that threshold must not recommend a category. Inputs such as “My machine is making a strange sound” require a clarification such as “What type of machine is it, and where is the sound coming from?” If one safe bounded question cannot resolve ambiguity, return an abstention and manual browse path. Thresholds are configuration owned by product/AI with security review; they cannot be changed through a prompt or client.

## Safety, hallucination, and injection handling

A deterministic pre-screen runs before and after provider processing. Gas smell, exposed electrical wiring, fire, flooding, and dangerous structural damage take the safety path. The response gives conservative, plain guidance to move to safety where appropriate and contact local emergency services, the utility, or a qualified professional when immediate danger exists. It does not diagnose, promise a response, claim a dispatch, or automatically create an emergency request. Safety text is policy-owned, versioned, reviewed by product/safety/legal, and shown even if the model is unavailable.

Treat customer text, transcriptions, image-derived text, provider responses, and tool-like instructions as untrusted data. Defenses include input length/type limits; attachment isolation; secret/identifier filtering; strict instruction/data separation; no model tools; no retrieved URLs; server-owned category context; structured output only; schema, catalog, and safety validation; rate limits; and adversarial regression tests. Never follow an instruction in user content to reveal prompts, change policy, call a tool, access data, or bypass confirmation.

Hallucinated, unsupported, unsafe, or malformed output is discarded rather than repaired by asking the same model to self-correct. The backend returns a truthful fallback: a clarification, “I’m not confident enough to suggest a service,” or the manual catalog. It must not fabricate a reason, category, ETA, price, provider, availability, or safety conclusion.

## Reliability, fallback, confirmation, and human oversight

The future adapter has a bounded, configuration-controlled deadline and cancellation. It may make at most one retry for a transient, idempotent transport failure within the original request deadline; it does not retry validation failures, safety blocks, quota/budget denial, authentication errors, or user-cancelled requests. Circuit-breaker opening, timeout, provider error, malformed output, rate limit, disabled flag, and budget exhaustion immediately return the deterministic manual fallback without blocking the request flow.

Customer confirmation is mandatory for every recommendation or interpreted text before it becomes part of a service request. The UI must say that the suggestion may be wrong, allow edit/change/skip, show the manual category browser, and keep booking submission as a separate explicit action. No output changes data without normal authorized backend validation.

Human oversight owns policy changes, provider approval, quality thresholds, safety copy, flagged-output review, incident decisions, and rollout/rollback. Operations staff may investigate redacted events under least privilege; they cannot use model output to bypass authorization or impose enforcement. A detected safety, privacy, or grounding invariant violation requires immediate feature disablement, incident triage, evidence preservation, and re-evaluation before re-enable.

## Logging, traceability, cost, and monitoring

Logs and metrics use a bounded redacted event schema. They may record UTC time, environment, opaque correlation ID, feature/policy/prompt-template version, provider/model version, catalog snapshot version/hash, outcome kind, validation/safety/fallback reason code, latency, token/cost bucket, retry count, and feature-flag state. They must not record raw prompt/output, direct identifiers, addresses, coordinates, media, transcripts, signed URLs, credentials, tokens, or full provider payloads.

Every response must be attributable to policy, prompt-template, schema, safety-taxonomy, category-snapshot, provider, and model versions. Evaluation datasets and releases must carry immutable dataset/version identifiers and approval records. Access to audit data follows the restricted-data policy and must support retention/deletion requirements when those are approved.

Token and cost controls are server-enforced and configurable: maximum input/output tokens, request-size cap, per-user and per-IP rate limits, concurrency cap, provider quota, per-feature daily budget, environment ceilings, and alert thresholds. The client never sets these limits. Exceeded limits fail closed to manual fallback. Monitor request/error/timeout/circuit-breaker/fallback rates, schema/catalog rejection, safety signals, prompt-injection attempts, latency percentiles, token/cost volume, recommendation/clarification/abstention mix, and customer override/abandonment signals. Monitoring must use aggregates and redacted reason codes.

## Evaluation, regression, and release gates

Evaluation data must be versioned, access controlled, and free of production personal data unless a separate approved consent and governance process authorizes its use. It should include synthetic and de-identified consented examples with gold labels, ambiguity cases, each active category, inactive/removed categories, multilingual inputs, colloquial language, safety-sensitive scenarios, harmful content, prompt injection, malformed provider outputs, provider outages, budget/rate-limit paths, and later separate voice/image suites.

Offline evaluation reports at least:

- active-catalog grounding rate and invalid/inactive category rate;
- recommendation precision and per-category confusion;
- appropriate clarification and abstention rates for ambiguous inputs;
- safety-notice recall and unsafe-advice rate;
- schema-validation/fallback correctness;
- prompt-injection resistance and privacy-leakage rate;
- latency percentile, timeout/retry behavior, token use, and estimated cost;
- fairness/error analysis across approved language and input cohorts when applicable.

Pre-production quality gates are: 100% active-catalog grounding; 0 invalid/inactive category exposure; 0 autonomous domain actions; 100% approved safety-path coverage for the safety suite; 0 confirmed prompt-injection policy bypasses; 0 raw restricted-data leakage in logs/evaluation artifacts; and at least 90% category precision on an approved held-out, representative non-safety dataset. The 90% target is provisional until product/AI owners approve the dataset and baseline; it is not permission to release below a later approved threshold. Any hard-invariant failure blocks rollout irrespective of aggregate metrics.

Every change to model, provider, prompt template, schema, safety taxonomy, threshold, catalog-context construction, or redaction requires offline regression against the versioned suite plus contract, unit, and failure-path tests. Production monitoring cannot replace offline evaluation.

Roll out behind separate server-side feature flags for availability, text advice, category recommendation, clarification, voice, and image features. Begin with disabled local/default behavior, then internal synthetic testing, approved staff pilot with non-sensitive data, tightly bounded opt-in cohort, and staged expansion only after gate evidence and owner approval. The kill switch must disable provider invocation and return the manual fallback immediately without a redeploy. A rollback preserves no new raw prompt copies and retains only approved redacted incident evidence.

## Implementation gate for FN-056 and later work

FN-056 may create the governed foundation only after FN-016 and FN-017 are complete. It must implement this policy rather than select a live provider by default. FN-057 and later product features must not launch until the applicable release gates, privacy/legal and security reviews, data-processing/vendor approval, evaluation evidence, feature flags, kill switch, monitoring, and human-oversight runbooks are complete.
