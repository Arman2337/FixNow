import { Injectable } from '@nestjs/common';
import { AiError } from '../contracts/ai-errors';
import {
  AiProvider,
  AiRequest,
  AiResponse,
} from '../contracts/ai-provider.contract';

export type DeterministicAiScenario =
  | 'success'
  | 'malformed_output'
  | 'timeout'
  | 'provider_unavailable'
  | 'rate_limited'
  | 'failure';

@Injectable()
export class DeterministicAiProvider extends AiProvider {
  constructor(
    private readonly scenario: DeterministicAiScenario = 'success',
    private readonly rawOutput = '{"value":"fake"}',
  ) {
    super();
  }

  generate(request: AiRequest): Promise<AiResponse> {
    switch (this.scenario) {
      case 'success':
        return Promise.resolve({
          rawOutput:
            this.rawOutput === '{"value":"fake"}' && request.catalog.length > 0
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

  private waitForAbort(signal: AbortSignal): Promise<AiResponse> {
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

@Injectable()
export class DisabledAiProvider extends AiProvider {
  generate(): Promise<AiResponse> {
    return Promise.reject(new AiError('AI_DISABLED'));
  }
}
