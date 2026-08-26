# Governed multimodal problem classification (FN-058 / FN-059)

FixNow customers can describe a household problem by **photo**, **voice**, or
**photo + voice**, and receive a structured, advisory classification (service
category, subcategory, technician-facing summary, urgency, and calibrated
confidence — plus the transcription for voice). This is assistance only: per
[ADR-0014](../architecture/decisions/0014-adopt-advisory-ai-governance.md) a
model never books, assigns a provider, or sets a price, and the customer always
confirms a category before any booking flow.

The pipeline and a real Hugging Face adapter are implemented, but the feature is
**disabled by default and blocked from live use until the ADR-0014 release gate
passes** (see [Governance gate status](#governance-gate-status)). All local
development and tests run on a deterministic provider — nothing leaves the
machine today.

## Models and why

| Modality | Model (default) | Notes |
| --- | --- | --- |
| Speech-to-text | `openai/whisper-large-v3` | Robust multilingual ASR (English, Hindi, Gujarati, and mixed speech). Hosted on HF Inference; no local GPU. |
| Image / combined | `Qwen/Qwen2.5-VL-7B-Instruct` | Open vision-language model with strong instruction-following for strict JSON output. Called via HF's OpenAI-compatible router. |

Both are hosted on the Hugging Face Inference API and reached with native
`fetch` — **no new dependency** is added. Models are configurable (see
[Swapping models](#swapping-models)); the provider is thin and replaceable.

## Boundary and layers

Everything lives under `backend/src/ai/problem-classification/` and reuses the
FN-056 foundation ([governed service foundation](governed-service-foundation.md)):

- `categories.config.ts` — the centralized FixNow **taxonomy**: the 11 category
  labels + subcategories + `Other`. This is the *only* label space the model may
  choose from, and the single editable source of truth (prompt, schema, and
  service all derive from it).
- `problem-classification.prompts.ts` — three reusable prompt builders (image /
  text-or-voice / combined). All ask for the **same** strict JSON shape, embed
  the taxonomy allow-list, forbid inventing categories, require an English
  technician summary, judge urgency from evidence only, and wrap the customer
  description as clearly-delimited untrusted data (prompt-injection guard).
- `problem-analysis.schema.ts` — the trust boundary. Raw model text is never
  application state: it parses the JSON, bounds every field, pins `category` to
  the taxonomy (unknown → coerced to `Other` with capped confidence), maps an
  unknown subcategory to `Other`, and clamps `confidence` to `[0, 1]`.
- `problem-classification.service.ts` — orchestrates transcription →
  classification → confidence banding → DB grounding → deterministic safety
  pre-screen. Every failure returns a clean `unavailable` result; it never
  throws.
- `problem-classification.controller.ts` — the three customer-authenticated
  multipart endpoints.

`AiService.transcribe` and `AiService.classifyMultimodal` are the only callers
of an `AiProvider`; they apply the shared guards (enabled/flag gates, per-user
rate limit, cancellation-aware timeout, media validation, metadata-only
logging, structured-output validation, deterministic fallback).

## Endpoints

All under the global `api/v1` prefix, `@Controller('ai/problem-analysis')`, each
customer-authenticated with `@RequireOwnPermission(PERMISSIONS.aiProblemAnalysisCreate)`
(customer role, own-resource). Requests are `multipart/form-data`.

| Method | Path | Fields |
| --- | --- | --- |
| `POST` | `/api/v1/ai/problem-analysis/image` | `image` (file) |
| `POST` | `/api/v1/ai/problem-analysis/voice` | `audio` (file), optional `languageHint` |
| `POST` | `/api/v1/ai/problem-analysis/combined` | `image` (file), `audio` (file), optional `languageHint` |

`languageHint` is advisory (e.g. `en`, `hi`, `gu`, `en-IN`); it is bounded to
letters/hyphens. A missing or unusable upload returns the same clean fallback
shape below — never a raw 500.

### Response

The contract is [`shared/problem-analysis.types.ts`](../../shared/problem-analysis.types.ts)
so mobile can consume it later without UI work now.

```jsonc
// success
{
  "kind": "analysis",
  "source": "image" | "voice" | "image_voice",
  "category": "Plumbing",            // always a taxonomy category (or "Other")
  "subcategory": "Pipe Leakage",     // a taxonomy subcategory (or "Other")
  "problemSummary": "…",             // concise, English, technician-facing
  "urgency": "low" | "medium" | "high",
  "confidence": 0.92,                // [0, 1]
  "confidenceBand": "high" | "medium" | "low",
  "transcription": "…",              // voice / image_voice only
  "serviceCategoryId": "…" | null,   // DB grounding, else null (advisory-only)
  "serviceName": "…" | null,         // server-derived catalog name, else null
  "safetyNotice": "…" | null         // deterministic guidance, else null
}
```

```jsonc
// fallback — client drops to manual category selection
{ "kind": "unavailable", "source": "…", "errorCode": "…" }
```

## Taxonomy

The 11 categories (`categories.config.ts`): **Plumbing, Electrical, AC Repair,
Refrigerator, Washing Machine, Water Heater, Gas/Stove, Carpentry, Painting,
Home Appliance, Other**. Each carries a short subcategory list and a stable
`slug` used for DB grounding. To change the taxonomy, edit this one file — the
prompt allow-list, schema validation, and grounding all follow automatically.

### DB grounding

The taxonomy is the classification label space, **not** the bookable catalog.
After a category is chosen, the service maps it to an active DB service category
(`ServiceCategoriesService.getActiveCategories()`) by `slug` or name and returns
`serviceCategoryId` + server-derived `serviceName` for the bookable handoff.
`Other` and any no-match stay advisory-only (`null`).

## Confidence policy

`confidenceBand` is derived from `confidence`:

| Band | Range | Intended client behavior |
| --- | --- | --- |
| `high` | ≥ 0.85 | Suggest the category (customer still confirms). |
| `medium` | 0.60–0.84 | Ask the customer to confirm. |
| `low` | < 0.60 | Fall back to manual selection / ask for more info. |

Coercing an unknown category to `Other` caps confidence at `0.5`, so a
mislabelled result can never present as a confident match.

## Safety pre-screen

A deterministic keyword scan over the transcript and model summary surfaces a
`safetyNotice` for gas, fire/smoke, electric shock/sparking, and flooding. It is
advisory guidance only — it never changes the classification or inflates
confidence.

## Error handling

Every failure maps to a stable `errorCode` on an `unavailable` result so the
client can always fall back to manual selection:

| Situation | `errorCode` |
| --- | --- |
| Invalid/oversized/empty/unsupported media | `INPUT_REJECTED` |
| Whisper/vision outage or network failure | `PROVIDER_UNAVAILABLE` |
| Deadline exceeded | `TIMEOUT` |
| Malformed/oversized JSON or missing fields | `INVALID_MODEL_OUTPUT` |
| Per-user rate limit exceeded | `RATE_LIMITED` |
| Feature disabled / modality flag off | `AI_DISABLED` |
| Provider lacks the capability | `UNSUPPORTED_OPERATION` |
| Unexpected internal error | `INTERNAL_AI_ERROR` |

An unknown model category is *not* an error — it is salvaged to `Other` with
capped confidence.

## Configuration

Documented with safe defaults in the root [`.env.example`](../../.env.example)
and validated in [`config/env.validation.ts`](../../backend/src/config/env.validation.ts).

| Variable | Safe default | Purpose |
| --- | --- | --- |
| `AI_VOICE_ENABLED` | `false` | FN-058 voice kill switch. |
| `AI_VISION_ENABLED` | `false` | FN-059 image kill switch. |
| `AI_MAX_IMAGE_BYTES` | `8388608` (8 MiB) | Per-request image ceiling → `INPUT_REJECTED`. |
| `AI_MAX_AUDIO_BYTES` | `15728640` (15 MiB) | Per-request audio ceiling → `INPUT_REJECTED`. |
| `HF_TOKEN` | *(empty)* | HF API token. **Server-side only**; never sent to the client, never logged, never committed. Required when `AI_PROVIDER=huggingface`. |
| `HF_INFERENCE_BASE_URL` | `https://router.huggingface.co/v1` | OpenAI-compatible chat-completions router (VLM). |
| `HF_ASR_BASE_URL` | `https://api-inference.huggingface.co/models` | Classic ASR host (Whisper). |
| `HF_VISION_MODEL` | `Qwen/Qwen2.5-VL-7B-Instruct` | Vision-language model id. |
| `HF_WHISPER_MODEL` | `openai/whisper-large-v3` | Speech-to-text model id. |

Startup validation fails closed: enabling either modality flag requires
`AI_ENABLED=true` and a non-disabled `AI_PROVIDER`; `AI_PROVIDER=huggingface`
requires `HF_TOKEN`; `fake` remains prohibited in production.

## How to run

**Local / tests (default, offline):**

```bash
AI_ENABLED=true AI_PROVIDER=fake AI_VISION_ENABLED=true AI_VOICE_ENABLED=true
```

The deterministic provider decodes audio bytes as the transcript and derives an
image hint from the uploaded bytes, producing schema-valid JSON with no network
call. POST the three endpoints and confirm the response matches the schema.

**Live (gated — only after the ADR-0014 gate passes):**

```bash
AI_ENABLED=true AI_PROVIDER=huggingface HF_TOKEN=hf_… AI_VISION_ENABLED=true AI_VOICE_ENABLED=true
```

### Swapping models

Point `HF_VISION_MODEL` / `HF_WHISPER_MODEL` at any HF-hosted equivalent (the
VLM must be reachable through the OpenAI-compatible router). To use a different
vendor entirely, implement the `AiProvider` port
(`transcribeAudio` + `analyzeMedia`) and register it in the `AI_PROVIDER`
factory in [`ai.module.ts`](../../backend/src/ai/ai.module.ts). Prompts and the
schema are provider-agnostic and need no change.

### CPU/GPU note

Inference is hosted by Hugging Face; the FixNow backend performs **no** local
model execution and requires no GPU. Media is held in memory only for the
duration of the request and is never persisted.

## Governance gate status

Per ADR-0014, raw customer images/audio are **Restricted** data and any external
transfer requires the multi-stakeholder release gate. This module ships the
pipeline and adapter **disabled and gated**:

- `AI_VOICE_ENABLED` / `AI_VISION_ENABLED` default off; production enablement is
  additionally gated on the release gate.
- The Hugging Face provider is never selected by tests and only when explicitly
  configured after the gate.
- **Documented limitation:** before `AI_VISION_ENABLED` may go live, the gate
  also requires EXIF stripping, malware scanning (the repo already runs ClamAV
  for provider documents), and signed DPA/retention terms. This module
  implements mime/size/empty + magic-byte validation now and marks the
  EXIF/scan hook; wiring an image codec/scanner is deferred (new dependency +
  gate work).

## Testing

Deterministic, no network or DB:

- `problem-classification.service.spec.ts` — image/voice/combined matrix,
  confidence banding, taxonomy coercion, DB grounding (match and no-match),
  safety notice, and every error path returning a clean fallback.
- `problem-classification.controller.spec.ts` — authorization boundary (only a
  customer reaches the service; provider/admin/inactive denied) and the
  missing-upload fallback.
- `problem-analysis.schema.spec.ts` — canonicalization, snake_case/camelCase
  reads, coercion + confidence cap, bounds/clamping, malformed rejection, and
  injection-text confinement.
- `evals/problem-classification-eval-v1.spec.ts` — versioned governance suite:
  label-space, grounding-rate, coercion, pinned banding thresholds, safety, the
  no-auto-book contract, and determinism gates.
- `config/env.validation.spec.ts` — HF-token requirement and modality-flag
  gating.
```
