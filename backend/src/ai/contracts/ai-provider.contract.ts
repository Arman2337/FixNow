export type AiOperation = 'structured_text';

export interface AiRequest {
  readonly operation: AiOperation;
  readonly requestId: string;
  readonly input: {
    readonly issueText: string;
    readonly locale?: string;
  };
  readonly catalog: readonly {
    readonly id: string;
    readonly name: string;
    readonly description?: string;
  }[];
  readonly maxOutputTokens: number;
  readonly signal: AbortSignal;
}

export interface AiModelMetadata {
  readonly provider: string;
  readonly model: string;
  readonly modelVersion?: string;
}

export interface AiUsage {
  readonly inputTokens?: number;
  readonly outputTokens?: number;
}

export interface AiResponse {
  readonly rawOutput: string;
  readonly metadata: AiModelMetadata;
  readonly usage?: AiUsage;
}

export abstract class AiProvider {
  abstract generate(request: AiRequest): Promise<AiResponse>;
}
