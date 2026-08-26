# FixNow AI documentation

FixNow AI features are planned assistance, not autonomous marketplace control. The governing reference is [AI governance and evaluation architecture](governance-and-evaluation-architecture.md). The durable cross-system decision is [ADR-0014](../architecture/decisions/0014-adopt-advisory-ai-governance.md).

No model provider, SDK, endpoint, prompt, or external AI data flow is approved by these documents.

The implemented backend-only [governed service foundation](governed-service-foundation.md) supplies a disabled-by-default provider boundary and deterministic test provider. It does not enable a live model or customer-facing recommendation feature.

The [voice and translation assistance boundary](voice-and-translation-assistance.md) documents FN-058's editable, no-audio-retention mobile flow and its provider/privacy release gate. It does not select or enable a speech or translation provider.

The [governed multimodal problem classification](problem-classification.md) reference documents the FN-058 / FN-059 image, voice, and combined pipeline: the centralized taxonomy, strict-JSON schema, confidence banding, DB grounding, and the real-but-gated Hugging Face adapter (Whisper + Qwen2.5-VL). It is disabled by default and blocked from live use until the ADR-0014 release gate passes; all tests run on the deterministic provider.
