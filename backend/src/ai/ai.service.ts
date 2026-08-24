import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { Logger } from 'nestjs-pino';
import { EnvironmentVariables, BooleanString } from '../config/env.validation';
import { AiError, AiErrorCode } from './contracts/ai-errors';
import {
  AiModelMetadata,
  AiProvider,
  AiUsage,
} from './contracts/ai-provider.contract';
import {
  SanitizedAiInput,
  sanitizeAiInput,
} from './policy/ai-request-sanitizer';
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

    const controller = new AbortController();
    const timeoutMs = this.numberConfig('AI_TIMEOUT_MS', 3_000);
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const externalAbort = () => controller.abort();
    operation.signal?.addEventListener('abort', externalAbort, { once: true });

    const startedAt = Date.now();
    try {
      const response = await this.provider.generate({
        operation: 'structured_text',
        requestId,
        input,
        catalog: operation.catalog ?? [],
        maxOutputTokens: this.numberConfig('AI_MAX_OUTPUT_TOKENS', 256),
        signal: controller.signal,
      });
      const value = parseStructuredOutput(
        response.rawOutput,
        operation.schema,
        this.numberConfig('AI_MAX_OUTPUT_TOKENS', 256) *
          MAX_CHARACTERS_PER_TOKEN,
      );
      this.logOperation({
        operation: safeOperation,
        requestId,
        outcome: 'success',
        durationMs: Date.now() - startedAt,
        metadata: response.metadata,
        usage: response.usage,
      });
      return {
        kind: 'success',
        value,
        metadata: response.metadata,
        ...(response.usage ? { usage: response.usage } : {}),
      };
    } catch (error) {
      const errorCode = controller.signal.aborted
        ? 'TIMEOUT'
        : this.errorCode(error);
      return this.fallback(errorCode, requestId, safeOperation, {
        durationMs: Date.now() - startedAt,
      });
    } finally {
      clearTimeout(timeout);
      operation.signal?.removeEventListener('abort', externalAbort);
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
      | 'AI_REQUEST_RATE_WINDOW_MS',
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
