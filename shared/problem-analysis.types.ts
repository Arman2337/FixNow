/**
 * FN-058 / FN-059: advisory multimodal problem-classification contracts.
 *
 * A classification is assistive guidance only. It never books, assigns a
 * provider, or determines a price (ADR-0014); the customer always confirms a
 * category before any booking flow. `serviceCategoryId` is a best-effort
 * grounding to the active DB service catalog and is `null` when there is no
 * confident match (the result stays advisory-only).
 */

export type ProblemAnalysisSource = 'image' | 'voice' | 'image_voice';

export type ProblemUrgency = 'low' | 'medium' | 'high';

/**
 * Derived from `confidence`: `high` ≥ 0.85, `medium` 0.60–0.84, `low` < 0.60.
 * The band drives the client's suggest / confirm / manual-selection behaviour.
 */
export type ProblemConfidenceBand = 'high' | 'medium' | 'low';

/**
 * Stable failure codes surfaced to the client so it can fall back to manual
 * category selection. Mirrors the backend `AiErrorCode` union by value; kept
 * as an independent literal union so `shared/` has no backend dependency.
 */
export type ProblemAnalysisErrorCode =
  | 'AI_DISABLED'
  | 'PROVIDER_UNAVAILABLE'
  | 'TIMEOUT'
  | 'RATE_LIMITED'
  | 'INVALID_MODEL_OUTPUT'
  | 'UNSUPPORTED_OPERATION'
  | 'INPUT_REJECTED'
  | 'INTERNAL_AI_ERROR';

export interface ProblemAnalysis {
  kind: 'analysis';
  source: ProblemAnalysisSource;
  /** One of the FixNow taxonomy categories; `Other` when unmappable. */
  category: string;
  /** A taxonomy subcategory hint, or `Other`. */
  subcategory: string;
  /** Concise, technician-facing description of the reported problem. */
  problemSummary: string;
  urgency: ProblemUrgency;
  /** Model-reported confidence in [0, 1]. */
  confidence: number;
  confidenceBand: ProblemConfidenceBand;
  /** Present for `voice` / `image_voice`; redacted before return. */
  transcription?: string;
  /** Active DB service-category id when grounded, else `null`. */
  serviceCategoryId: string | null;
  /** Server-derived catalog name when grounded, else `null`. */
  serviceName: string | null;
  /** Deterministic safety guidance (gas/fire/shock/flooding), else `null`. */
  safetyNotice: string | null;
}

export interface ProblemAnalysisUnavailable {
  kind: 'unavailable';
  source: ProblemAnalysisSource;
  errorCode: ProblemAnalysisErrorCode;
}

export type ProblemAnalysisResult =
  | ProblemAnalysis
  | ProblemAnalysisUnavailable;
