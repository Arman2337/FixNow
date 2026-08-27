import { Injectable } from '@nestjs/common';
import {
  ProblemAnalysisResult,
  ProblemAnalysisSource,
  ProblemConfidenceBand,
} from '../../../../shared/problem-analysis.types';
import { ServiceCategoriesService } from '../../services/service-categories.service';
import { ServiceCategoryEntity } from '../../services/service-category.entity';
import { AiService } from '../ai.service';
import { OTHER_CATEGORY, slugFor } from './categories.config';
import {
  ClassifiedProblem,
  problemAnalysisSchema,
} from './problem-analysis.schema';
import {
  buildCombinedClassificationPrompt,
  buildImageClassificationPrompt,
  buildTextClassificationPrompt,
} from './problem-classification.prompts';

interface MediaInput {
  readonly bytes: Buffer;
  readonly mimeType: string;
}

export interface ImageAnalysisInput {
  readonly userId: string;
  readonly image: MediaInput;
  readonly requestId?: string;
}

export interface VoiceAnalysisInput {
  readonly userId: string;
  readonly audio: MediaInput;
  readonly languageHint?: string;
  readonly requestId?: string;
}

export interface CombinedAnalysisInput {
  readonly userId: string;
  readonly image: MediaInput;
  readonly audio: MediaInput;
  readonly languageHint?: string;
  readonly requestId?: string;
}

/**
 * Advisory multimodal problem classification (FN-058 voice, FN-059 image).
 *
 * Orchestrates transcription → classification → confidence banding → DB
 * grounding → deterministic safety pre-screen, returning a clean, schema-shaped
 * result. Every failure path returns `{ kind: 'unavailable', errorCode }` so
 * the client can fall back to manual category selection — it never throws.
 */
@Injectable()
export class ProblemClassificationService {
  constructor(
    private readonly ai: AiService,
    private readonly categories: ServiceCategoriesService,
  ) {}

  async analyzeImage(
    input: ImageAnalysisInput,
  ): Promise<ProblemAnalysisResult> {
    const classified = await this.ai.classifyMultimodal({
      userId: input.userId,
      image: input.image,
      prompt: buildImageClassificationPrompt(),
      schema: problemAnalysisSchema,
      ...(input.requestId ? { requestId: input.requestId } : {}),
    });
    if (classified.kind === 'fallback')
      return {
        kind: 'unavailable',
        source: 'image',
        errorCode: classified.errorCode,
      };
    return this.toAnalysis('image', classified.value, undefined);
  }

  async analyzeVoice(
    input: VoiceAnalysisInput,
  ): Promise<ProblemAnalysisResult> {
    const transcript = await this.transcribe(input);
    if (transcript.kind === 'unavailable') return transcript;

    const classified = await this.ai.classifyMultimodal({
      userId: input.userId,
      issueText: transcript.text,
      prompt: buildTextClassificationPrompt({
        issueText: transcript.text,
        ...(input.languageHint ? { languageHint: input.languageHint } : {}),
      }),
      schema: problemAnalysisSchema,
      ...(input.requestId ? { requestId: input.requestId } : {}),
    });
    if (classified.kind === 'fallback')
      return {
        kind: 'unavailable',
        source: 'voice',
        errorCode: classified.errorCode,
      };
    return this.toAnalysis('voice', classified.value, transcript.text);
  }

  async analyzeCombined(
    input: CombinedAnalysisInput,
  ): Promise<ProblemAnalysisResult> {
    const transcript = await this.transcribe({
      ...input,
      source: 'image_voice',
    });
    if (transcript.kind === 'unavailable') return transcript;

    const classified = await this.ai.classifyMultimodal({
      userId: input.userId,
      image: input.image,
      issueText: transcript.text,
      prompt: buildCombinedClassificationPrompt({
        issueText: transcript.text,
        ...(input.languageHint ? { languageHint: input.languageHint } : {}),
      }),
      schema: problemAnalysisSchema,
      ...(input.requestId ? { requestId: input.requestId } : {}),
    });
    if (classified.kind === 'fallback')
      return {
        kind: 'unavailable',
        source: 'image_voice',
        errorCode: classified.errorCode,
      };
    return this.toAnalysis('image_voice', classified.value, transcript.text);
  }

  /** Transcribe, returning either the redacted text or an `unavailable` result. */
  private async transcribe(
    input: VoiceAnalysisInput & { source?: ProblemAnalysisSource },
  ): Promise<
    | { kind: 'text'; text: string }
    | (ProblemAnalysisResult & { kind: 'unavailable' })
  > {
    const source: ProblemAnalysisSource = input.source ?? 'voice';
    const result = await this.ai.transcribe({
      userId: input.userId,
      audio: input.audio,
      ...(input.languageHint ? { languageHint: input.languageHint } : {}),
      ...(input.requestId ? { requestId: input.requestId } : {}),
    });
    if (result.kind === 'fallback')
      return { kind: 'unavailable', source, errorCode: result.errorCode };
    return { kind: 'text', text: result.value.transcription };
  }

  private async toAnalysis(
    source: ProblemAnalysisSource,
    classified: ClassifiedProblem,
    transcription: string | undefined,
  ): Promise<ProblemAnalysisResult> {
    const grounding = await this.ground(classified.category);
    return {
      kind: 'analysis',
      source,
      category: classified.category,
      subcategory: classified.subcategory,
      problemSummary: classified.problemSummary,
      urgency: classified.urgency,
      confidence: classified.confidence,
      confidenceBand: bandFor(classified.confidence),
      ...(transcription !== undefined ? { transcription } : {}),
      serviceCategoryId: grounding?.id ?? null,
      serviceName: grounding?.name ?? null,
      safetyNotice: detectSafetyNotice(
        [transcription ?? '', classified.problemSummary].join(' '),
      ),
    };
  }

  /**
   * Best-effort mapping of a taxonomy category to an active DB service category
   * by slug or name. Returns null (advisory-only) for "Other" or no match.
   */
  private async ground(
    categoryName: string,
  ): Promise<{ id: string; name: string } | null> {
    if (categoryName === OTHER_CATEGORY) return null;
    const active = await this.categories.getActiveCategories();
    const slug = slugFor(categoryName);
    const normalizedName = categoryName.toLowerCase();
    const match = active.find(
      (category: ServiceCategoryEntity) =>
        (slug !== undefined && category.slug?.toLowerCase() === slug) ||
        category.name.toLowerCase() === normalizedName,
    );
    return match ? { id: match.id, name: match.name } : null;
  }
}

function bandFor(confidence: number): ProblemConfidenceBand {
  if (confidence >= 0.85) return 'high';
  if (confidence >= 0.6) return 'medium';
  return 'low';
}

const GAS_NOTICE =
  'If you smell gas, do not use switches or flames — move to fresh air and contact the gas utility or emergency services.';
const FIRE_NOTICE =
  'If there is fire or smoke, move to safety and contact local emergency services immediately.';
const SHOCK_NOTICE =
  'If you see sparking or risk of electric shock, switch off the mains if safe to do so and keep away from the area.';
const FLOOD_NOTICE =
  'If water is flooding, shut off the supply valve if safe to do so to limit damage.';

/**
 * Deterministic safety pre-screen. Runs on the transcript and model summary
 * only; it never changes the classification or confidence — it just surfaces
 * guidance alongside it.
 */
function detectSafetyNotice(text: string): string | null {
  const value = text.toLowerCase();
  if (/\bgas\b|gas\s*leak|lpg|smell.*gas/.test(value)) return GAS_NOTICE;
  if (/\bfire\b|smoke|burning/.test(value)) return FIRE_NOTICE;
  if (/\bshock\b|electrocut|spark(?:ing)?\b|live wire/.test(value))
    return SHOCK_NOTICE;
  if (/flood(?:ing)?|burst pipe|gushing|water everywhere/.test(value))
    return FLOOD_NOTICE;
  return null;
}
