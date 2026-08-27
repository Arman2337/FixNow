/**
 * Hugging Face AI adapter (FN-058 Whisper + FN-059 Qwen2.5-VL). Implements the
 * provider port over the HF Inference API using native `fetch` (Node 20+, no
 * new dependency).
 *
 * GOVERNANCE (ADR-0014): this is a real, working adapter but it is NOT enabled
 * by default and is blocked from production startup until the multi-stakeholder
 * release gate passes. It is never used by tests (the deterministic provider
 * is). See `docs/ai/problem-classification.md`.
 *
 * The provider is intentionally thin: prompts are composed by the
 * classification layer and passed in as `prompt`. The provider never persists
 * media, never logs payloads, and never echoes the token.
 */

import { Injectable } from '@nestjs/common';
import { AiError } from '../contracts/ai-errors';
import {
  AiMultimodalRequest,
  AiProvider,
  AiRequest,
  AiResponse,
  AiTranscriptionRequest,
  AiTranscriptionResponse,
} from '../contracts/ai-provider.contract';

export interface HuggingFaceAiProviderConfig {
  /** Server-side only. Never returned or logged. */
  readonly token: string;
  /** OpenAI-compatible chat-completions base, e.g. https://router.huggingface.co/v1 */
  readonly chatBaseUrl: string;
  /** Classic ASR inference host, e.g. https://api-inference.huggingface.co/models */
  readonly asrBaseUrl: string;
  /** Vision-language model id, e.g. Qwen/Qwen2.5-VL-7B-Instruct */
  readonly visionModel: string;
  /** Speech-to-text model id, e.g. openai/whisper-large-v3 */
  readonly whisperModel: string;
}

interface ChatMessage {
  readonly role: 'system' | 'user';
  readonly content: string | ChatContentPart[];
}

type ChatContentPart =
  | { readonly type: 'text'; readonly text: string }
  | {
      readonly type: 'image_url';
      readonly image_url: { readonly url: string };
    };

@Injectable()
export class HuggingFaceAiProvider extends AiProvider {
  constructor(private readonly config: HuggingFaceAiProviderConfig) {
    super();
  }

  /**
   * Text structured output (FN-057 path). The provider owns text prompt
   * construction here, mirroring the deterministic provider, and grounds the
   * model on the caller-supplied catalog.
   */
  async generate(request: AiRequest): Promise<AiResponse> {
    const catalog = request.catalog
      .map(
        (entry) =>
          `- ${entry.id}: ${entry.name}${entry.description ? ` (${entry.description})` : ''}`,
      )
      .join('\n');
    const system = [
      "Classify the customer's home-service issue into exactly one catalog service.",
      'Respond with ONLY minified JSON, one of:',
      '{"kind":"recommendation","serviceCategoryId":<id>,"confidence":<0..1>,"reason":<string>}',
      '{"kind":"clarification","clarificationQuestion":<string>}',
      '{"kind":"no_match"}',
      'serviceCategoryId MUST be one of the listed ids. Never invent an id.',
      `Catalog:\n${catalog}`,
    ].join('\n');
    const content = await this.chatCompletion(
      this.config.visionModel,
      [
        { role: 'system', content: system },
        { role: 'user', content: request.input.issueText },
      ],
      request.maxOutputTokens,
      request.signal,
    );
    return this.toResponse(content, this.config.visionModel);
  }

  /** Speech-to-text via Whisper (raw audio body). */
  async transcribeAudio(
    request: AiTranscriptionRequest,
  ): Promise<AiTranscriptionResponse> {
    this.assertConfigured();
    const url = `${trimSlash(this.config.asrBaseUrl)}/${this.config.whisperModel}`;
    // A Node `Buffer` is typed `Uint8Array<ArrayBufferLike>`, which `fetch`'s
    // `BodyInit` rejects (it requires an `ArrayBuffer`-backed view). The copying
    // `Uint8Array(...)` constructor yields a concrete `ArrayBuffer` backing, so
    // the raw audio body stays byte-identical and is well-typed.
    const audioBody = new Uint8Array(request.audio.bytes);
    const response = await this.fetchJson(url, {
      method: 'POST',
      headers: {
        ...this.authHeaders(),
        'Content-Type': request.audio.mimeType,
      },
      body: audioBody,
      signal: request.signal,
    });
    const transcription = extractTranscription(response);
    if (transcription === undefined) throw new AiError('INVALID_MODEL_OUTPUT');
    return {
      transcription,
      metadata: { provider: 'huggingface', model: this.config.whisperModel },
    };
  }

  /** Vision-language classification with an optional image + composed prompt. */
  async analyzeMedia(request: AiMultimodalRequest): Promise<AiResponse> {
    const parts: ChatContentPart[] = [{ type: 'text', text: request.prompt }];
    if (request.image) {
      const dataUrl = `data:${request.image.mimeType};base64,${request.image.bytes.toString('base64')}`;
      parts.push({ type: 'image_url', image_url: { url: dataUrl } });
    }
    const content = await this.chatCompletion(
      this.config.visionModel,
      [{ role: 'user', content: parts }],
      request.maxOutputTokens,
      request.signal,
    );
    return this.toResponse(content, this.config.visionModel);
  }

  private async chatCompletion(
    model: string,
    messages: ChatMessage[],
    maxTokens: number,
    signal: AbortSignal,
  ): Promise<string> {
    this.assertConfigured();
    const url = `${trimSlash(this.config.chatBaseUrl)}/chat/completions`;
    const json = await this.fetchJson(url, {
      method: 'POST',
      headers: {
        ...this.authHeaders(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages,
        max_tokens: maxTokens,
        temperature: 0,
      }),
      signal,
    });
    const content = extractContent(json);
    if (content === undefined) throw new AiError('INVALID_MODEL_OUTPUT');
    return content;
  }

  private async fetchJson(
    url: string,
    init: RequestInit,
  ): Promise<Record<string, unknown> & { text?: unknown; choices?: unknown }> {
    let response: Response;
    try {
      response = await fetch(url, init);
    } catch {
      // Network failure / abort. When aborted, AiService maps this to TIMEOUT
      // via the controller signal; otherwise it is a provider outage.
      throw new AiError('PROVIDER_UNAVAILABLE');
    }
    if (!response.ok) {
      throw new AiError(
        response.status === 429 ? 'RATE_LIMITED' : 'PROVIDER_UNAVAILABLE',
      );
    }
    try {
      return (await response.json()) as Record<string, unknown>;
    } catch {
      throw new AiError('INVALID_MODEL_OUTPUT');
    }
  }

  private toResponse(rawOutput: string, model: string): AiResponse {
    return {
      rawOutput,
      metadata: { provider: 'huggingface', model },
    };
  }

  private authHeaders(): Record<string, string> {
    return { Authorization: `Bearer ${this.config.token}` };
  }

  private assertConfigured(): void {
    if (!this.config.token) throw new AiError('PROVIDER_UNAVAILABLE');
  }
}

/**
 * Whisper responses are `{ "text": "..." }`, but some routes return an array of
 * segments (`[{ "text": "..." }]`). Narrow through `unknown` so no `any`
 * escapes into the caller (keeps the type-checked lint clean).
 */
function extractTranscription(payload: unknown): string | undefined {
  if (payload === null || typeof payload !== 'object') return undefined;
  const direct = (payload as { text?: unknown }).text;
  if (typeof direct === 'string') return direct;
  if (Array.isArray(payload)) {
    const first = (payload as unknown[])[0];
    const nested = (first as { text?: unknown } | undefined)?.text;
    if (typeof nested === 'string') return nested;
  }
  return undefined;
}

function extractContent(json: { choices?: unknown }): string | undefined {
  const choices = json.choices;
  if (!Array.isArray(choices) || choices.length === 0) return undefined;
  const message = (choices[0] as { message?: { content?: unknown } })?.message;
  const content = message?.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    const text = content
      .map((part: unknown) =>
        typeof (part as { text?: unknown })?.text === 'string'
          ? (part as { text: string }).text
          : '',
      )
      .join('');
    return text.length > 0 ? text : undefined;
  }
  return undefined;
}

function trimSlash(value: string): string {
  return value.endsWith('/') ? value.slice(0, -1) : value;
}
