import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { Logger } from 'nestjs-pino';
import { EnvironmentVariables, BooleanString } from '../config/env.validation';
import { AiError, AiErrorCode } from './contracts/ai-errors';
import {
  AiCatalogEntry,
  AiModelMetadata,
  AiProvider,
  AiUsage,
} from './contracts/ai-provider.contract';
import {
  SanitizedAiInput,
  redactSensitiveText,
  sanitizeAiInput,
} from './policy/ai-request-sanitizer';
import {
  assertAllowedAudio,
  assertAllowedImage,
  stripImageMetadata,
} from './policy/ai-media-policy';
import {
  StructuredOutputSchema,
  parseStructuredOutput,
} from './validation/structured-output.validator';

const MAX_CHARACTERS_PER_TOKEN = 4;

interface AiOperationalLogger {
  info(metadata: Record<string, unknown>, message: string): void;
}

export interface AiStructuredOperation<T> {
  readonly operation: string;
  readonly userId: string;
  readonly issueText: unknown;
  readonly locale?: unknown;
  readonly schema: StructuredOutputSchema<T>;
  readonly requestId?: string;
  readonly signal?: AbortSignal;
  readonly catalog?: readonly {
    readonly id: string;
    readonly name: string;
    readonly description?: string;
  }[];
}

/** Audio transcription operation (FN-058). */
export interface AiTranscriptionOperation {
  readonly userId: string;
  readonly audio: { readonly bytes: Buffer; readonly mimeType: string };
  readonly languageHint?: string;
  readonly requestId?: string;
  readonly signal?: AbortSignal;
}

export interface AiTranscriptionValue {
  readonly transcription: string;
  readonly detectedLanguage?: string;
}

/**
 * Multimodal classification operation (FN-059 image, and image+text). The
 * prompt is composed by the caller (centralized prompt templates) and any text
 * must already be redacted by the caller — `AiService` treats `prompt`/
 * `issueText` as opaque and never logs them.
 */
export interface AiMultimodalOperation<T> {
  readonly userId: string;
  readonly image?: { readonly bytes: Buffer; readonly mimeType: string };
  readonly issueText?: string;
  readonly prompt: string;
  readonly schema: StructuredOutputSchema<T>;
  readonly catalog?: readonly AiCatalogEntry[];
  readonly requestId?: string;
  readonly signal?: AbortSignal;
}

export type AiExecutionResult<T> =
  | {
      readonly kind: 'success';
      readonly value: T;
      readonly metadata: AiModelMetadata;
      readonly usage?: AiUsage;
    }
  | {
      readonly kind: 'fallback';
      readonly errorCode: AiErrorCode;
    };

@Injectable()
export class AiService {
  private readonly requestTimestamps = new Map<string, number[]>();

  constructor(
    private readonly config: ConfigService<EnvironmentVariables>,
    private readonly provider: AiProvider,
    private readonly logger: Logger,
  ) {}

  async executeStructured<T>(
    operation: AiStructuredOperation<T>,
  ): Promise<AiExecutionResult<T>> {
    const requestId = operation.requestId ?? randomUUID();
    const safeOperation =
      operation.operation === 'structured_text'
        ? operation.operation
        : 'unsupported';
    if (this.config.get('AI_ENABLED') !== BooleanString.True)
      return this.fallback('AI_DISABLED', requestId, safeOperation);
    if (operation.operation !== 'structured_text')
      return this.fallback('UNSUPPORTED_OPERATION', requestId, safeOperation);

    let input: SanitizedAiInput;
    try {
      input = sanitizeAiInput({
        issueText: operation.issueText,
        locale: operation.locale,
      });
      this.assertWithinRateLimit(operation.userId);
    } catch (error) {
      return this.fallback(this.errorCode(error), requestId, safeOperation);
    }

    const maxOutputTokens = this.numberConfig('AI_MAX_OUTPUT_TOKENS', 256);
    return this.runGuarded<T>({
      operation: safeOperation,
      requestId,
      externalSignal: operation.signal,
      run: async (signal) => {
        const response = await this.provider.generate({
          operation: 'structured_text',
          requestId,
          input,
          catalog: operation.catalog ?? [],
          maxOutputTokens,
          signal,
        });
        const value = parseStructuredOutput(
          response.rawOutput,
          operation.schema,
          maxOutputTokens * MAX_CHARACTERS_PER_TOKEN,
        );
        return {
          value,
          metadata: response.metadata,
          ...(response.usage ? { usage: response.usage } : {}),
        };
      },
    });
  }

  /**
   * Transcribe audio to text (FN-058). Gated by `AI_ENABLED` and the
   * `AI_VOICE_ENABLED` per-feature flag. The returned transcript is redacted
   * before it leaves this service so downstream callers/logs never see raw
   * sensitive fragments.
   */
  async transcribe(
    operation: AiTranscriptionOperation,
  ): Promise<AiExecutionResult<AiTranscriptionValue>> {
    const requestId = operation.requestId ?? randomUUID();
    const label = 'transcribe_audio';
    if (this.config.get('AI_ENABLED') !== BooleanString.True)
      return this.fallback('AI_DISABLED', requestId, label);
    if (this.config.get('AI_VOICE_ENABLED') !== BooleanString.True)
      return this.fallback('AI_DISABLED', requestId, label);
    const transcribeAudio = this.provider.transcribeAudio?.bind(this.provider);
    if (!transcribeAudio)
      return this.fallback('UNSUPPORTED_OPERATION', requestId, label);

    try {
      assertAllowedAudio(
        operation.audio,
        this.numberConfig('AI_MAX_AUDIO_BYTES', 15 * 1024 * 1024),
      );
      this.assertWithinRateLimit(operation.userId);
    } catch (error) {
      return this.fallback(this.errorCode(error), requestId, label);
    }

    return this.runGuarded<AiTranscriptionValue>({
      operation: label,
      requestId,
      externalSignal: operation.signal,
      run: async (signal) => {
        const response = await transcribeAudio({
          operation: 'transcribe_audio',
          requestId,
          audio: operation.audio,
          ...(operation.languageHint
            ? { languageHint: operation.languageHint }
            : {}),
          signal,
        });
        const transcription = redactSensitiveText(
          (response.transcription ?? '').trim(),
        );
        if (!transcription) throw new AiError('INVALID_MODEL_OUTPUT');
        return {
          value: {
            transcription,
            ...(response.detectedLanguage
              ? { detectedLanguage: response.detectedLanguage }
              : {}),
          },
          metadata: response.metadata,
          ...(response.usage ? { usage: response.usage } : {}),
        };
      },
    });
  }

  /**
   * Vision-language / multimodal classification (FN-059). Gated by
   * `AI_ENABLED`, and by `AI_VISION_ENABLED` whenever an image is present.
   * Validates the image, then parses the provider output through the
   * caller-supplied schema. At least one of `image` / `issueText` is required.
   */
  async classifyMultimodal<T>(
    operation: AiMultimodalOperation<T>,
  ): Promise<AiExecutionResult<T>> {
    const requestId = operation.requestId ?? randomUUID();
    const label = 'classify_multimodal';
    if (this.config.get('AI_ENABLED') !== BooleanString.True)
      return this.fallback('AI_DISABLED', requestId, label);
    if (
      operation.image &&
      this.config.get('AI_VISION_ENABLED') !== BooleanString.True
    )
      return this.fallback('AI_DISABLED', requestId, label);
    const analyzeMedia = this.provider.analyzeMedia?.bind(this.provider);
    if (!analyzeMedia)
      return this.fallback('UNSUPPORTED_OPERATION', requestId, label);
    if (!operation.image && !operation.issueText?.trim())
      return this.fallback('INPUT_REJECTED', requestId, label);

    let image = operation.image;
    try {
      if (image) {
        assertAllowedImage(
          image,
          this.numberConfig('AI_MAX_IMAGE_BYTES', 8 * 1024 * 1024),
        );
        // Strip EXIF/XMP/IPTC before the image crosses the provider boundary.
        // Runs only after validation and behind AI_VISION_ENABLED.
        image = stripImageMetadata(image);
      }
      this.assertWithinRateLimit(operation.userId);
    } catch (error) {
      return this.fallback(this.errorCode(error), requestId, label);
    }

    const maxOutputTokens = this.numberConfig('AI_MAX_OUTPUT_TOKENS', 256);
    return this.runGuarded<T>({
      operation: label,
      requestId,
      externalSignal: operation.signal,
      run: async (signal) => {
        const response = await analyzeMedia({
          operation: 'classify_multimodal',
          requestId,
          ...(image ? { image } : {}),
          ...(operation.issueText ? { issueText: operation.issueText } : {}),
          catalog: operation.catalog ?? [],
          prompt: operation.prompt,
          maxOutputTokens,
          signal,
        });
        const value = parseStructuredOutput(
          response.rawOutput,
          operation.schema,
          maxOutputTokens * MAX_CHARACTERS_PER_TOKEN,
        );
        return {
          value,
          metadata: response.metadata,
          ...(response.usage ? { usage: response.usage } : {}),
        };
      },
    });
  }

  /**
   * Shared cross-cutting execution: bounded deadline, external-cancellation
   * propagation, success logging, and deterministic error→fallback mapping.
   * Every provider call in this service goes through here so the timeout,
   * abort, and logging semantics stay identical across operations.
   */
  private async runGuarded<T>(params: {
    readonly operation: string;
    readonly requestId: string;
    readonly externalSignal?: AbortSignal;
    readonly run: (signal: AbortSignal) => Promise<{
      value: T;
      metadata: AiModelMetadata;
      usage?: AiUsage;
    }>;
  }): Promise<AiExecutionResult<T>> {
    const controller = new AbortController();
    const timeoutMs = this.numberConfig('AI_TIMEOUT_MS', 3_000);
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const externalAbort = () => controller.abort();
    params.externalSignal?.addEventListener('abort', externalAbort, {
      once: true,
    });

    const startedAt = Date.now();
    try {
      const { value, metadata, usage } = await params.run(controller.signal);
      this.logOperation({
        operation: params.operation,
        requestId: params.requestId,
        outcome: 'success',
        durationMs: Date.now() - startedAt,
        metadata,
        usage,
      });
      return {
        kind: 'success',
        value,
        metadata,
        ...(usage ? { usage } : {}),
      };
    } catch (error) {
      const errorCode = controller.signal.aborted
        ? 'TIMEOUT'
        : this.errorCode(error);
      return this.fallback(errorCode, params.requestId, params.operation, {
        durationMs: Date.now() - startedAt,
      });
    } finally {
      clearTimeout(timeout);
      params.externalSignal?.removeEventListener('abort', externalAbort);
    }
  }

  private assertWithinRateLimit(userId: string): void {
    const now = Date.now();
    const windowMs = this.numberConfig('AI_REQUEST_RATE_WINDOW_MS', 60_000);
    const limit = this.numberConfig('AI_REQUEST_RATE_LIMIT', 10);
    const timestamps = (this.requestTimestamps.get(userId) ?? []).filter(
      (timestamp) => now - timestamp < windowMs,
    );
    if (timestamps.length >= limit) throw new AiError('RATE_LIMITED');
    timestamps.push(now);
    this.requestTimestamps.set(userId, timestamps);
  }

  private fallback(
    errorCode: AiErrorCode,
    requestId: string,
    operation: string,
    details?: { durationMs?: number },
  ): AiExecutionResult<never> {
    this.logOperation({
      operation,
      requestId,
      outcome: errorCode,
      ...(details?.durationMs !== undefined
        ? { durationMs: details.durationMs }
        : {}),
    });
    return { kind: 'fallback', errorCode };
  }

  private errorCode(error: unknown): AiErrorCode {
    return error instanceof AiError ? error.code : 'INTERNAL_AI_ERROR';
  }

  private numberConfig(
    key:
      | 'AI_TIMEOUT_MS'
      | 'AI_MAX_OUTPUT_TOKENS'
      | 'AI_REQUEST_RATE_LIMIT'
      | 'AI_REQUEST_RATE_WINDOW_MS'
      | 'AI_MAX_IMAGE_BYTES'
      | 'AI_MAX_AUDIO_BYTES',
    fallback: number,
  ): number {
    return this.config.get<number>(key, fallback);
  }

  private logOperation(event: {
    readonly operation: string;
    readonly requestId: string;
    readonly outcome: string;
    readonly durationMs?: number;
    readonly metadata?: AiModelMetadata;
    readonly usage?: AiUsage;
  }): void {
    const logger = this.logger as unknown as AiOperationalLogger;
    logger.info(
      {
        ai: {
          operation: event.operation,
          requestId: event.requestId,
          outcome: event.outcome,
          ...(event.durationMs !== undefined
            ? { durationMs: event.durationMs }
            : {}),
          ...(event.metadata
            ? {
                provider: event.metadata.provider,
                model: event.metadata.model,
                ...(event.metadata.modelVersion
                  ? { modelVersion: event.metadata.modelVersion }
                  : {}),
              }
            : {}),
          ...(event.usage
            ? {
                inputTokens: event.usage.inputTokens,
                outputTokens: event.usage.outputTokens,
              }
            : {}),
        },
      },
      'AI operation completed',
    );
  }
}
