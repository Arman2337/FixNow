/**
 * Provider-neutral AI port. Extended for FN-058/FN-059 with two optional
 * multimodal capabilities (audio transcription and image/text classification)
 * alongside the original text `generate`. Capabilities are optional so a
 * provider can implement only what it supports; `AiService` treats a missing
 * capability as `UNSUPPORTED_OPERATION` rather than crashing.
 *
 * A provider receives only a bounded, purpose-specific request and returns
 * untrusted structured data. It has no domain tools, database access, or write
 * authority (ADR-0014).
 */

export type AiOperation =
  'structured_text' | 'transcribe_audio' | 'classify_multimodal';

export interface AiCatalogEntry {
  readonly id: string;
  readonly name: string;
  readonly description?: string;
}

/** In-memory media payload. Never persisted; never logged. */
export interface AiMediaPayload {
  readonly bytes: Buffer;
  readonly mimeType: string;
}

export interface AiRequest {
  readonly operation: 'structured_text';
  readonly requestId: string;
  readonly input: {
    readonly issueText: string;
    readonly locale?: string;
  };
  readonly catalog: readonly AiCatalogEntry[];
  readonly maxOutputTokens: number;
  readonly signal: AbortSignal;
}

export interface AiTranscriptionRequest {
  readonly operation: 'transcribe_audio';
  readonly requestId: string;
  readonly audio: AiMediaPayload;
  /** Optional BCP-47-ish hint (e.g. 'en', 'hi', 'gu'); undefined = auto. */
  readonly languageHint?: string;
  readonly signal: AbortSignal;
}

export interface AiTranscriptionResponse {
  readonly transcription: string;
  readonly detectedLanguage?: string;
  readonly metadata: AiModelMetadata;
  readonly usage?: AiUsage;
}

/**
 * Vision-language classification. The composed prompt is built in the
 * classification layer (centralized prompt templates) and passed in, so the
 * provider stays thin and swappable. At least one of `image` / `issueText`
 * is present; the classification service enforces that.
 */
export interface AiMultimodalRequest {
  readonly operation: 'classify_multimodal';
  readonly requestId: string;
  readonly image?: AiMediaPayload;
  readonly issueText?: string;
  readonly catalog: readonly AiCatalogEntry[];
  readonly prompt: string;
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
  /** Text structured output (FN-057). Always implemented. */
  abstract generate(request: AiRequest): Promise<AiResponse>;

  /** Speech-to-text (FN-058). Optional capability. */
  transcribeAudio?(
    request: AiTranscriptionRequest,
  ): Promise<AiTranscriptionResponse>;

  /** Vision-language / multimodal classification (FN-059). Optional capability. */
  analyzeMedia?(request: AiMultimodalRequest): Promise<AiResponse>;
}
