# Governed AI service foundation

FN-056 provides a backend-only, provider-neutral foundation for later AI features. It does not expose an AI HTTP endpoint and does not implement category recommendation, booking changes, provider assignment, voice, translation, image analysis, pricing, payments, ratings, or reviews.

## Boundary

`backend/src/ai/` has four layers:

- `contracts/` defines the provider-neutral request, response, model metadata, usage, and stable error codes.
- `providers/` contains the deterministic fake provider for local/test use and the disabled provider.
- `policy/` allow-lists the only initial prompt fields, applies bounded input validation, and redacts common email, phone, coordinate, OTP, and authorization-token patterns before a provider boundary.
- `validation/` parses JSON and validates it through a caller-supplied structured-output schema. Raw model text is never application state.

`AiService` is the only application layer that calls an `AiProvider`. It accepts only `structured_text`, enforces a per-user in-memory rate window, cancellation-aware timeout, bounded output, metadata-only logging, and deterministic fallback. Future controllers or domain services consume `AiService`; they must never call a vendor SDK directly.

## Configuration and kill switch

The root `.env.example` documents these validated server settings:

| Variable | Safe default | Purpose |
| --- | --- | --- |
| `AI_ENABLED` | `false` | Global feature flag/kill switch. Disabled requests return `AI_DISABLED` fallback. |
| `AI_PROVIDER` | `disabled` | `disabled` or `fake`; unknown values fail startup validation. |
| `AI_MODEL` | `not-configured` | Future provider model label only. |
| `AI_TIMEOUT_MS` | `3000` | Bounded adapter deadline. |
| `AI_MAX_OUTPUT_TOKENS` | `256` | Output budget and structured-output size bound. |
| `AI_REQUEST_RATE_LIMIT` | `10` | Per-user requests per rate window. |
| `AI_REQUEST_RATE_WINDOW_MS` | `60000` | Per-user burst-control window. |

The fake provider is prohibited in production by startup validation. No production provider or credential is approved or configured. When disabled, the foundation does no provider call; normal service discovery and booking flows remain independent.

## Result, error, and retry behavior

`AiService.executeStructured` returns either a validated `success` result with model/usage metadata or a `fallback` result with one stable error code:

- `AI_DISABLED`
- `PROVIDER_UNAVAILABLE`
- `TIMEOUT`
- `RATE_LIMITED`
- `INVALID_MODEL_OUTPUT`
- `UNSUPPORTED_OPERATION`
- `INPUT_REJECTED`
- `INTERNAL_AI_ERROR`

No raw provider exception, prompt, or model response is returned. FN-056 makes no retries: future adapters may add at most one idempotent transient retry only when it stays inside the original deadline and is covered by tests. It must never retry client validation, policy denial, malformed output, budget/rate-limit denial, or cancellation.

## Privacy and logging

The initial operation accepts only issue text and an optional locale. It does not accept account identity, booking context, contacts, location, authentication material, OTPs, provider data, KYC content, media, or internal security metadata. The policy further redacts common sensitive fragments in permitted free text before calling a provider. This is defense in depth, not authorization to send other fields.

AI logs contain only operation, opaque request ID, outcome/error class, duration, provider/model/version, and token counts when supplied. They never include raw input, raw output, coordinates, OTP, credentials, or provider exceptions. See [AI governance and evaluation architecture](governance-and-evaluation-architecture.md) for the full data and retention policy.

## Deterministic fake provider and FN-057 handoff

`DeterministicAiProvider` supports successful JSON, malformed output, timeout/cancellation, provider unavailable, rate limited, and explicit failure scenarios without a network call. Unit tests use it or a local mock only.

FN-057 may define an issue-classification schema and pass it to `executeStructured`. It must still supply only active, server-owned service-category context; validate category IDs against the active catalog; derive category names on the server; show confidence/clarification/abstention to the customer; and require customer confirmation before any ordinary booking flow. It must not add a live provider without the approval gates in the governance policy.

## Issue classification and service recommendation

`POST /ai/service-recommendation` is customer-authenticated and accepts only a bounded issue description plus optional bounded clarification context. It returns `RECOMMENDATION`, `CLARIFICATION`, `NO_MATCH`, or `UNAVAILABLE`; it never creates a booking or assigns a provider. The backend passes only active category ID/name/description context to the governed AI service, then validates the returned ID against the current active catalog and derives the returned name from that catalog.

The mobile Ask FixNow AI entry opens a focused assistant. A recommendation must be explicitly continued by the customer, which returns the selected category to the existing service-request screen. Clarification, no-match, safety, and unavailable states remain manual and usable. Tests use the deterministic fake provider; no live AI call is used.
