# ADR-0014: Adopt advisory AI governance and a provider-neutral boundary

- Status: Accepted
- Date: 2026-08-21
- Owners: FixNow product, AI, security, and privacy owners

## Context

FixNow plans assistance for natural-language issue descriptions, service-category recommendations, and clarification questions. Voice transcription/translation and issue-image analysis are later capabilities. These features can make an urgent request easier to describe, but a model can be wrong, unsafe, manipulated, unavailable, or inappropriate for personal data.

The existing service catalog is authoritative. `ServiceCategory` has an ID, name, `isActive`, and `isEmergency` fields, and the backend already exposes active-category queries. AI output must never bypass that catalog or FixNow's booking, authorization, emergency, payment, or privacy controls.

## Decision

AI is advisory only. The model may help a customer understand their description, suggest an existing active category, or ask one bounded clarifying question. It has no tools or authority to create a booking, assign a provider, dispatch emergency services, change a lifecycle state, access payments/pricing, or create ratings/reviews.

Future integrations use a backend-owned provider port. The mobile and admin clients call a versioned backend advisory contract; the backend performs authorization, data minimization, policy checks, active-catalog snapshotting, schema validation, safety handling, audit redaction, and confirmation handling. A provider adapter receives only a purpose-limited request and returns untrusted structured data. It cannot receive client credentials, domain write access, raw database access, or unrestricted tools.

For a category recommendation, the model may choose only from a short, backend-supplied snapshot of active catalog IDs and neutral labels. The backend validates the returned ID against the same active snapshot before exposing it. The backend, not the model, derives the displayed service name from the validated category. An absent, inactive, stale, malformed, or unknown ID becomes an abstention or clarification, never a substitute category.

The normative policy, output contract, data boundaries, evaluation gates, and rollout requirements are in [AI governance and evaluation architecture](../../ai/governance-and-evaluation-architecture.md). No model, provider, prompt, SDK, endpoint, dataset, or external AI call is introduced by this decision.

## Consequences

- Customers retain control: they review an advisory result and explicitly select a category and submit any booking.
- The manual category browser and request flow remain available when AI is disabled, slow, unsafe, low confidence, or unavailable.
- A future implementation must build the policy gate, provider port, schemas, redaction, evaluation harness, feature flags, metrics, and operations controls before enabling a provider.
- Provider selection, data-processing terms, jurisdiction/residency, retention schedule, supported languages, production quality baselines, and accountable approvers remain release gates. This ADR does not choose a vendor or authorize external processing.

## Alternatives considered

- **Client-to-model calls:** rejected because clients cannot reliably enforce authorization, secret handling, catalog grounding, redaction, audit, cost, or a kill switch.
- **Free-form model recommendations:** rejected because they can invent services, present diagnoses as fact, or make consequential claims outside FixNow's catalog.
- **Model-driven booking, matching, or emergency action:** rejected because these are consequential domain actions that require deterministic policy and explicit user or authorized human control.
- **No AI policy until implementation:** rejected because vendor/data/prompt choices become difficult to reverse once code or customer data is involved.

## Validation

Before any AI provider or feature is enabled, the implementation must satisfy the policy's hard invariants, schema and contract tests, adversarial offline evaluation, privacy/security review, cost/latency/fallback tests, feature-flag and kill-switch exercises, and documented product, AI, privacy/legal, and security approval. Reconsider this decision if evidence shows the advisory boundary cannot prevent unsafe or ungrounded outcomes.
