import { ConfigService } from '@nestjs/config';
import { Logger } from 'nestjs-pino';
import { AiService } from './ai.service';
import {
  AiProvider,
  AiRequest,
  AiResponse,
} from './contracts/ai-provider.contract';
import { DeterministicAiProvider } from './providers/deterministic-ai.provider';
import { StructuredOutputSchema } from './validation/structured-output.validator';

interface FixtureOutput {
  value: string;
}

const fixtureSchema: StructuredOutputSchema<FixtureOutput> = {
  parse(value: unknown): FixtureOutput | null {
    if (
      typeof value === 'object' &&
      value !== null &&
      'value' in value &&
      typeof value.value === 'string'
    ) {
      return { value: value.value };
    }
    return null;
  },
};

describe('AiService', () => {
  const loggerInfo = jest.fn();

  beforeEach(() => jest.clearAllMocks());

  function createService(
    provider: AiProvider,
    values: Record<string, unknown> = {},
  ): AiService {
    const config = {
      get: jest.fn((key: string, fallback?: unknown) =>
        key in values ? values[key] : fallback,
      ),
    } as unknown as ConfigService;
    const logger = { info: loggerInfo } as unknown as Logger;
    return new AiService(config, provider, logger);
  }

  function request(issueText = 'The kitchen sink is leaking') {
    return {
      operation: 'structured_text',
      userId: 'user-1',
      issueText,
      schema: fixtureSchema,
      requestId: 'request-1',
    } as const;
  }

  it('returns a deterministic fake-provider structured response with metadata', async () => {
    const service = createService(new DeterministicAiProvider(), {
      AI_ENABLED: 'true',
    });

    await expect(service.executeStructured(request())).resolves.toEqual({
      kind: 'success',
      value: { value: 'fake' },
      metadata: { provider: 'fake', model: 'deterministic', modelVersion: '1' },
      usage: { inputTokens: 1, outputTokens: 1 },
    });
  });

  it('returns deterministic fallbacks for disabled, unavailable, timeout, and malformed output paths', async () => {
    await expect(
      createService(new DeterministicAiProvider()).executeStructured(request()),
    ).resolves.toEqual({ kind: 'fallback', errorCode: 'AI_DISABLED' });
    await expect(
      createService(new DeterministicAiProvider('provider_unavailable'), {
        AI_ENABLED: 'true',
      }).executeStructured(request()),
    ).resolves.toEqual({ kind: 'fallback', errorCode: 'PROVIDER_UNAVAILABLE' });
    await expect(
      createService(new DeterministicAiProvider('timeout'), {
        AI_ENABLED: 'true',
        AI_TIMEOUT_MS: 5,
      }).executeStructured(request()),
    ).resolves.toEqual({ kind: 'fallback', errorCode: 'TIMEOUT' });
    await expect(
      createService(new DeterministicAiProvider('malformed_output'), {
        AI_ENABLED: 'true',
      }).executeStructured(request()),
    ).resolves.toEqual({ kind: 'fallback', errorCode: 'INVALID_MODEL_OUTPUT' });
  });

  it('does not invoke the provider for unsupported operations, oversized input, or local rate limits', async () => {
    const provider = new DeterministicAiProvider();
    const service = createService(provider, {
      AI_ENABLED: 'true',
      AI_REQUEST_RATE_LIMIT: 1,
    });

    await expect(
      service.executeStructured({ ...request(), operation: 'unknown' }),
    ).resolves.toEqual({
      kind: 'fallback',
      errorCode: 'UNSUPPORTED_OPERATION',
    });
    await expect(
      service.executeStructured(request('x'.repeat(1_001))),
    ).resolves.toEqual({
      kind: 'fallback',
      errorCode: 'INPUT_REJECTED',
    });
    await expect(service.executeStructured(request())).resolves.toMatchObject({
      kind: 'success',
    });
    await expect(
      service.executeStructured({ ...request(), requestId: 'request-2' }),
    ).resolves.toEqual({
      kind: 'fallback',
      errorCode: 'RATE_LIMITED',
    });
  });

  it('allow-lists and redacts text before provider use and logs only safe metadata', async () => {
    const generate = jest
      .fn<Promise<AiResponse>, [AiRequest]>()
      .mockResolvedValue({
        rawOutput: '{"value":"fake"}',
        metadata: { provider: 'fake', model: 'deterministic' },
      });
    const service = createService({ generate }, { AI_ENABLED: 'true' });
    const sensitive =
      'Email me@example.com, phone 9876543210, coordinates 22.8982, 72.9928, OTP 123456';

    await expect(
      service.executeStructured(request(sensitive)),
    ).resolves.toMatchObject({
      kind: 'success',
    });

    const providerRequest = generate.mock.calls[0]?.[0];
    expect(providerRequest?.input.issueText).not.toContain('me@example.com');
    expect(providerRequest?.input.issueText).not.toContain('9876543210');
    expect(providerRequest?.input.issueText).not.toContain('22.8982');
    expect(providerRequest?.input.issueText).not.toContain('123456');
    expect(JSON.stringify(loggerInfo.mock.calls)).not.toContain(
      'me@example.com',
    );
    expect(JSON.stringify(loggerInfo.mock.calls)).not.toContain('9876543210');
    expect(JSON.stringify(loggerInfo.mock.calls)).not.toContain('22.8982');
    expect(JSON.stringify(loggerInfo.mock.calls)).not.toContain('123456');
  });
});
