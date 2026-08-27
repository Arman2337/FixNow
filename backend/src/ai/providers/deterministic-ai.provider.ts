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

export type DeterministicAiScenario =
  | 'success'
  | 'malformed_output'
  | 'timeout'
  | 'provider_unavailable'
  | 'rate_limited'
  | 'failure';

const DEFAULT_RAW_OUTPUT = '{"value":"fake"}';

@Injectable()
export class DeterministicAiProvider extends AiProvider {
  constructor(
    private readonly scenario: DeterministicAiScenario = 'success',
    private readonly rawOutput = DEFAULT_RAW_OUTPUT,
  ) {
    super();
  }

  generate(request: AiRequest): Promise<AiResponse> {
    switch (this.scenario) {
      case 'success':
        return Promise.resolve({
          rawOutput:
            this.rawOutput === DEFAULT_RAW_OUTPUT && request.catalog.length > 0
              ? classificationFixture(request)
              : this.rawOutput,
          metadata: {
            provider: 'fake',
            model: 'deterministic',
            modelVersion: '1',
          },
          usage: { inputTokens: 1, outputTokens: 1 },
        });
      case 'malformed_output':
        return Promise.resolve({
          rawOutput: '{',
          metadata: {
            provider: 'fake',
            model: 'deterministic',
            modelVersion: '1',
          },
        });
      case 'provider_unavailable':
        return Promise.reject(new AiError('PROVIDER_UNAVAILABLE'));
      case 'rate_limited':
        return Promise.reject(new AiError('RATE_LIMITED'));
      case 'failure':
        return Promise.reject(new Error('deterministic provider failure'));
      case 'timeout':
        return this.waitForAbort(request.signal);
    }
  }

  /**
   * Deterministic speech-to-text for local/test use: the "transcript" is the
   * audio buffer decoded as UTF-8 text. Tests therefore drive a transcript by
   * passing `Buffer.from('...')` as the audio bytes; nothing leaves the machine.
   */
  transcribeAudio(
    request: AiTranscriptionRequest,
  ): Promise<AiTranscriptionResponse> {
    const rejection = this.scenarioRejection();
    if (rejection) return rejection;
    if (this.scenario === 'timeout') return this.waitForAbort(request.signal);
    const transcription =
      this.scenario === 'malformed_output'
        ? '' // empty transcript -> caller maps to INVALID_MODEL_OUTPUT
        : request.audio.bytes.toString('utf8').trim();
    return Promise.resolve({
      transcription,
      detectedLanguage: request.languageHint ?? 'en',
      metadata: { provider: 'fake', model: 'deterministic', modelVersion: '1' },
      usage: { inputTokens: 1, outputTokens: 1 },
    });
  }

  /**
   * Deterministic multimodal classification for local/test use. Derives its
   * hint text from `issueText` and, for an image, the image buffer decoded as
   * UTF-8 (append a hint after the magic bytes in tests). Emits the same JSON
   * shape the real prompt asks for.
   */
  analyzeMedia(request: AiMultimodalRequest): Promise<AiResponse> {
    const rejection = this.scenarioRejection();
    if (rejection) return rejection;
    if (this.scenario === 'timeout') return this.waitForAbort(request.signal);
    if (this.scenario === 'malformed_output') {
      return Promise.resolve({
        rawOutput: '{',
        metadata: {
          provider: 'fake',
          model: 'deterministic',
          modelVersion: '1',
        },
      });
    }
    const hintText = [
      request.issueText ?? '',
      request.image ? request.image.bytes.toString('utf8') : '',
    ]
      .join(' ')
      .toLowerCase();
    return Promise.resolve({
      rawOutput:
        this.rawOutput === DEFAULT_RAW_OUTPUT
          ? problemClassificationFixture(hintText)
          : this.rawOutput,
      metadata: { provider: 'fake', model: 'deterministic', modelVersion: '1' },
      usage: { inputTokens: 1, outputTokens: 1 },
    });
  }

  private scenarioRejection(): Promise<never> | null {
    switch (this.scenario) {
      case 'provider_unavailable':
        return Promise.reject(new AiError('PROVIDER_UNAVAILABLE'));
      case 'rate_limited':
        return Promise.reject(new AiError('RATE_LIMITED'));
      case 'failure':
        return Promise.reject(new Error('deterministic provider failure'));
      default:
        return null;
    }
  }

  private waitForAbort(signal: AbortSignal): Promise<never> {
    return new Promise((_, reject) => {
      if (signal.aborted) {
        reject(new AiError('TIMEOUT'));
        return;
      }
      signal.addEventListener('abort', () => reject(new AiError('TIMEOUT')), {
        once: true,
      });
    });
  }
}

function classificationFixture(request: AiRequest): string {
  const text = request.input.issueText.toLowerCase();
  const safetyNotice = text.includes('gas')
    ? 'If you smell gas, move to a safe area and contact local emergency services or the utility.'
    : text.includes('fire') || text.includes('smoke')
      ? 'If there is fire or smoke, move to safety and contact local emergency services.'
      : null;
  if (safetyNotice != null) {
    return JSON.stringify({ kind: 'no_match', safetyNotice });
  }
  if (
    text.includes('machine') ||
    text.includes('noise') ||
    text.includes("don't know")
  ) {
    return JSON.stringify({
      kind: 'clarification',
      clarificationQuestion:
        'What type of machine or appliance is making the noise?',
    });
  }
  const category = request.catalog.find((item) =>
    text.includes('sink') || text.includes('pipe') || text.includes('leak')
      ? item.name.toLowerCase().includes('plumb')
      : text.includes('power') ||
          text.includes('electric') ||
          text.includes('wiring')
        ? item.name.toLowerCase().includes('electric')
        : text.includes('lock') || text.includes('key')
          ? item.name.toLowerCase().includes('lock')
          : false,
  );
  if (!category) return JSON.stringify({ kind: 'no_match' });
  return JSON.stringify({
    kind: 'recommendation',
    serviceCategoryId: category.id,
    confidence: 0.94,
    reason: 'This matches the service description you provided.',
  });
}

/**
 * Deterministic multimodal classification producing the problem-analysis JSON
 * shape (snake_case, as the prompt requests). Keyword-driven so tests are
 * predictable across image / voice / combined modes.
 */
function problemClassificationFixture(text: string): string {
  const hazard = /\b(gas|fire|smoke|spark|shock|flood(?:ing)?)\b/.test(text);
  const match = matchCategory(text);
  if (!match) {
    return JSON.stringify({
      category: 'Other',
      subcategory: 'Other',
      problem_summary:
        'The reported issue could not be confidently matched to a known service category.',
      urgency: 'low',
      confidence: 0.3,
    });
  }
  return JSON.stringify({
    category: match.category,
    subcategory: match.subcategory,
    problem_summary: match.summary,
    urgency: hazard ? 'high' : match.urgency,
    confidence: match.confidence,
  });
}

interface CategoryMatch {
  category: string;
  subcategory: string;
  summary: string;
  urgency: 'low' | 'medium' | 'high';
  confidence: number;
}

function matchCategory(text: string): CategoryMatch | null {
  const has = (...terms: string[]) => terms.some((term) => text.includes(term));
  if (has('washing machine', 'washer'))
    return match('Washing Machine', 'Not Draining', 'medium', 0.9);
  if (has('refrigerator', 'fridge'))
    return match('Refrigerator', 'Not Cooling', 'medium', 0.9);
  if (has('air condition', 'a/c', ' ac ', 'cooling', 'aircon'))
    return match('AC Repair', 'Not Cooling', 'medium', 0.9);
  if (has('geyser', 'water heater', 'hot water'))
    return match('Water Heater', 'No Hot Water', 'medium', 0.88);
  if (has('stove', 'burner', 'gas leak', 'lpg'))
    return match('Gas/Stove', 'Gas Leak', 'high', 0.9);
  if (has('pipe', 'sink', 'leak', 'tap', 'faucet', 'drain', 'toilet', 'water'))
    return match('Plumbing', 'Pipe Leakage', 'high', 0.92);
  if (has('socket', 'switch', 'wiring', 'electric', 'spark', 'shock', 'power'))
    return match('Electrical', 'Wiring Fault', 'high', 0.9);
  if (has('paint')) return match('Painting', 'Interior Wall', 'low', 0.85);
  if (has('door', 'furniture', 'cabinet', 'hinge', 'wood'))
    return match('Carpentry', 'Furniture Repair', 'medium', 0.85);
  if (has('microwave', 'television', 'chimney', 'mixer', 'dishwasher'))
    return match('Home Appliance', 'Microwave', 'medium', 0.82);
  return null;
}

function match(
  category: string,
  subcategory: string,
  urgency: 'low' | 'medium' | 'high',
  confidence: number,
): CategoryMatch {
  return {
    category,
    subcategory,
    summary: `Likely ${category.toLowerCase()} issue reported by the customer.`,
    urgency,
    confidence,
  };
}

@Injectable()
export class DisabledAiProvider extends AiProvider {
  generate(): Promise<AiResponse> {
    return Promise.reject(new AiError('AI_DISABLED'));
  }

  transcribeAudio(): Promise<AiTranscriptionResponse> {
    return Promise.reject(new AiError('AI_DISABLED'));
  }

  analyzeMedia(): Promise<AiResponse> {
    return Promise.reject(new AiError('AI_DISABLED'));
  }
}
