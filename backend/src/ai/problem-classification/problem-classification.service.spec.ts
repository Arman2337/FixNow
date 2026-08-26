import { ConfigService } from '@nestjs/config';
import { Logger } from 'nestjs-pino';
import {
  ProblemAnalysis,
  ProblemAnalysisResult,
} from '../../../../shared/problem-analysis.types';
import { ServiceCategoriesService } from '../../services/service-categories.service';
import { ServiceCategoryEntity } from '../../services/service-category.entity';
import { AiService } from '../ai.service';
import {
  DeterministicAiProvider,
  DeterministicAiScenario,
} from '../providers/deterministic-ai.provider';
import { isAllowedCategory, subcategoriesFor } from './categories.config';
import { ProblemClassificationService } from './problem-classification.service';

/**
 * Active DB catalog used for grounding. Deliberately omits "Painting" so a
 * valid taxonomy category can still ground to `null` (advisory-only).
 */
const ACTIVE_CATEGORIES = [
  { id: 'cat-plumbing', name: 'Plumbing', slug: 'plumbing', isActive: true },
  {
    id: 'cat-electrical',
    name: 'Electrical',
    slug: 'electrical',
    isActive: true,
  },
  { id: 'cat-ac', name: 'AC Repair', slug: 'ac-repair', isActive: true },
  {
    id: 'cat-washer',
    name: 'Washing Machine',
    slug: 'washing-machine',
    isActive: true,
  },
  {
    id: 'cat-water-heater',
    name: 'Water Heater',
    slug: 'water-heater',
    isActive: true,
  },
  { id: 'cat-gas', name: 'Gas/Stove', slug: 'gas-stove', isActive: true },
] as unknown as ServiceCategoryEntity[];

const IMAGE_CFG = {
  AI_ENABLED: 'true',
  AI_VISION_ENABLED: 'true',
  AI_REQUEST_RATE_LIMIT: 1000,
};
const VOICE_CFG = {
  AI_ENABLED: 'true',
  AI_VOICE_ENABLED: 'true',
  AI_REQUEST_RATE_LIMIT: 1000,
};
const COMBINED_CFG = {
  AI_ENABLED: 'true',
  AI_VOICE_ENABLED: 'true',
  AI_VISION_ENABLED: 'true',
  AI_REQUEST_RATE_LIMIT: 1000,
};

const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff]);

/** A schema-valid JPEG payload whose trailing UTF-8 text drives the fixture. */
function jpeg(hint: string): { bytes: Buffer; mimeType: string } {
  return {
    bytes: Buffer.concat([JPEG_MAGIC, Buffer.from(` ${hint}`)]),
    mimeType: 'image/jpeg',
  };
}

function audio(
  transcript: string,
  mimeType = 'audio/mpeg',
): { bytes: Buffer; mimeType: string } {
  return { bytes: Buffer.from(transcript), mimeType };
}

function build(
  values: Record<string, unknown>,
  scenario: DeterministicAiScenario = 'success',
  rawOutput?: string,
): { service: ProblemClassificationService } {
  const config = {
    get: jest.fn((key: string, fallback?: unknown) =>
      key in values ? values[key] : fallback,
    ),
  } as unknown as ConfigService;
  const logger = { info: jest.fn() } as unknown as Logger;
  const provider =
    rawOutput === undefined
      ? new DeterministicAiProvider(scenario)
      : new DeterministicAiProvider(scenario, rawOutput);
  const ai = new AiService(config, provider, logger);
  const categories = {
    getActiveCategories: jest.fn().mockResolvedValue(ACTIVE_CATEGORIES),
  } as unknown as ServiceCategoriesService;
  return { service: new ProblemClassificationService(ai, categories) };
}

/** Asserts the contract every successful analysis must satisfy. */
function expectValidAnalysis(result: ProblemAnalysisResult): ProblemAnalysis {
  expect(result.kind).toBe('analysis');
  if (result.kind !== 'analysis') throw new Error('expected analysis');
  expect(isAllowedCategory(result.category)).toBe(true);
  const subs = subcategoriesFor(result.category);
  expect(
    result.subcategory === 'Other' || subs.includes(result.subcategory),
  ).toBe(true);
  expect(['low', 'medium', 'high']).toContain(result.urgency);
  expect(result.confidence).toBeGreaterThanOrEqual(0);
  expect(result.confidence).toBeLessThanOrEqual(1);
  const expectedBand =
    result.confidence >= 0.85
      ? 'high'
      : result.confidence >= 0.6
        ? 'medium'
        : 'low';
  expect(result.confidenceBand).toBe(expectedBand);
  return result;
}

describe('ProblemClassificationService', () => {
  const userId = 'customer-1';

  describe('image', () => {
    it.each([
      ['pipe leak under the sink', 'Plumbing', 'cat-plumbing'],
      ['electrical socket not working', 'Electrical', 'cat-electrical'],
      ['air conditioner not cooling', 'AC Repair', 'cat-ac'],
      ['washing machine not draining', 'Washing Machine', 'cat-washer'],
    ])(
      'classifies "%s" as %s and grounds it to the active catalog',
      async (hint, category, serviceCategoryId) => {
        const { service } = build(IMAGE_CFG);

        const result = await service.analyzeImage({
          userId,
          image: jpeg(hint),
        });

        const analysis = expectValidAnalysis(result);
        expect(analysis.source).toBe('image');
        expect(analysis.category).toBe(category);
        expect(analysis.serviceCategoryId).toBe(serviceCategoryId);
        expect(analysis.serviceName).toBe(category);
        // Image-only carries no transcription.
        expect(analysis.transcription).toBeUndefined();
      },
    );

    it('returns a low-confidence "Other" analysis for an unclear photo', async () => {
      const { service } = build(IMAGE_CFG);

      const result = await service.analyzeImage({
        userId,
        image: jpeg('a blurry unidentifiable object'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.category).toBe('Other');
      expect(analysis.confidenceBand).toBe('low');
      // No confident match → advisory only.
      expect(analysis.serviceCategoryId).toBeNull();
      expect(analysis.serviceName).toBeNull();
    });
  });

  describe('voice', () => {
    it.each([
      ['en', 'my kitchen sink pipe is leaking badly', 'Plumbing'],
      ['mixed', 'AC ठीक से cooling नहीं कर रहा है', 'AC Repair'],
    ])(
      'transcribes and classifies a %s description',
      async (languageHint, transcript, category) => {
        const { service } = build(VOICE_CFG);

        const result = await service.analyzeVoice({
          userId,
          audio: audio(transcript),
          languageHint,
        });

        const analysis = expectValidAnalysis(result);
        expect(analysis.source).toBe('voice');
        expect(analysis.category).toBe(category);
        expect(analysis.transcription).toBe(transcript);
      },
    );

    it.each([
      ['hi', 'मेरा नल टपक रहा है'],
      ['gu', 'પાણી લીક થઈ રહ્યું છે'],
      ['en', 'umm i am really not sure what is wrong'],
    ])(
      'always returns the transcription for a %s description even when unmapped',
      async (languageHint, transcript) => {
        const { service } = build(VOICE_CFG);

        const result = await service.analyzeVoice({
          userId,
          audio: audio(transcript),
          languageHint,
        });

        const analysis = expectValidAnalysis(result);
        expect(analysis.source).toBe('voice');
        expect(analysis.transcription).toBe(transcript);
      },
    );
  });

  describe('combined', () => {
    it('agreeing image + voice produce a grounded classification with transcription', async () => {
      const { service } = build(COMBINED_CFG);

      const result = await service.analyzeCombined({
        userId,
        image: jpeg('air conditioner unit'),
        audio: audio('the ac is not cooling'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.source).toBe('image_voice');
      expect(analysis.category).toBe('AC Repair');
      expect(analysis.serviceCategoryId).toBe('cat-ac');
      expect(analysis.transcription).toBe('the ac is not cooling');
    });

    it('recovers a category from the image when the voice is unclear', async () => {
      const { service } = build(COMBINED_CFG);

      const result = await service.analyzeCombined({
        userId,
        image: jpeg('washing machine drum'),
        audio: audio('umm i am not sure'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.category).toBe('Washing Machine');
      expect(analysis.transcription).toBe('umm i am not sure');
    });

    it('recovers a category from the voice when the image is unclear', async () => {
      const { service } = build(COMBINED_CFG);

      const result = await service.analyzeCombined({
        userId,
        image: jpeg('a blurry photo'),
        audio: audio('my geyser has no hot water'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.category).toBe('Water Heater');
      expect(analysis.serviceCategoryId).toBe('cat-water-heater');
    });

    it('falls back to low-confidence "Other" when both signals are unclear', async () => {
      const { service } = build(COMBINED_CFG);

      const result = await service.analyzeCombined({
        userId,
        image: jpeg('a blurry photo'),
        audio: audio('i really do not know'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.category).toBe('Other');
      expect(analysis.confidenceBand).toBe('low');
    });
  });

  describe('confidence banding', () => {
    it.each([
      [0.9, 'high'],
      [0.85, 'high'],
      [0.84, 'medium'],
      [0.6, 'medium'],
      [0.59, 'low'],
      [0.3, 'low'],
    ])('bands confidence %s as %s', async (confidence, band) => {
      const { service } = build(
        IMAGE_CFG,
        'success',
        JSON.stringify({
          category: 'Plumbing',
          subcategory: 'Pipe Leakage',
          problem_summary: 'A pipe under the sink is leaking.',
          urgency: 'medium',
          confidence,
        }),
      );

      const result = await service.analyzeImage({ userId, image: jpeg('x') });

      const analysis = expectValidAnalysis(result);
      expect(analysis.confidence).toBe(confidence);
      expect(analysis.confidenceBand).toBe(band);
    });
  });

  describe('taxonomy grounding', () => {
    it('coerces an unknown category to "Other" and caps confidence', async () => {
      const { service } = build(
        IMAGE_CFG,
        'success',
        JSON.stringify({
          category: 'Quantum Teleporter',
          subcategory: 'Warp Core',
          problem_summary: 'An unmappable contraption.',
          urgency: 'low',
          confidence: 0.99,
        }),
      );

      const result = await service.analyzeImage({ userId, image: jpeg('x') });

      const analysis = expectValidAnalysis(result);
      expect(analysis.category).toBe('Other');
      expect(analysis.subcategory).toBe('Other');
      expect(analysis.confidence).toBeLessThanOrEqual(0.5);
      expect(analysis.serviceCategoryId).toBeNull();
      expect(analysis.serviceName).toBeNull();
    });

    it('stays advisory-only when a valid category is absent from the catalog', async () => {
      const { service } = build(IMAGE_CFG);

      // "Painting" is a valid taxonomy category but not in ACTIVE_CATEGORIES.
      const result = await service.analyzeImage({
        userId,
        image: jpeg('the wall needs fresh paint'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.category).toBe('Painting');
      expect(analysis.serviceCategoryId).toBeNull();
      expect(analysis.serviceName).toBeNull();
    });
  });

  describe('safety pre-screen', () => {
    it('surfaces a gas safety notice from the transcript without inflating confidence', async () => {
      const { service } = build(VOICE_CFG);

      const result = await service.analyzeVoice({
        userId,
        audio: audio('i can smell gas near the stove in the kitchen'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.safetyNotice).not.toBeNull();
      expect(analysis.safetyNotice?.toLowerCase()).toContain('gas');
    });

    it('does not attach a safety notice to a routine issue', async () => {
      const { service } = build(VOICE_CFG);

      const result = await service.analyzeVoice({
        userId,
        audio: audio('the wall needs a fresh coat of paint'),
      });

      const analysis = expectValidAnalysis(result);
      expect(analysis.safetyNotice).toBeNull();
    });
  });

  describe('error paths return a clean fallback (never throw)', () => {
    it('rejects an image with a disallowed mime type', async () => {
      const { service } = build(IMAGE_CFG);

      const result = await service.analyzeImage({
        userId,
        image: { bytes: jpeg('x').bytes, mimeType: 'image/gif' },
      });

      expect(result).toEqual({
        kind: 'unavailable',
        source: 'image',
        errorCode: 'INPUT_REJECTED',
      });
    });

    it('rejects an image that exceeds the configured byte cap', async () => {
      const { service } = build({ ...IMAGE_CFG, AI_MAX_IMAGE_BYTES: 4 });

      const result = await service.analyzeImage({
        userId,
        image: jpeg('a photo larger than four bytes'),
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        errorCode: 'INPUT_REJECTED',
      });
    });

    it('rejects empty audio', async () => {
      const { service } = build(VOICE_CFG);

      const result = await service.analyzeVoice({
        userId,
        audio: { bytes: Buffer.alloc(0), mimeType: 'audio/mpeg' },
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        source: 'voice',
        errorCode: 'INPUT_REJECTED',
      });
    });

    it('maps a provider outage to PROVIDER_UNAVAILABLE', async () => {
      const { service } = build(VOICE_CFG, 'provider_unavailable');

      const result = await service.analyzeVoice({
        userId,
        audio: audio('my sink is leaking'),
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        errorCode: 'PROVIDER_UNAVAILABLE',
      });
    });

    it('maps a deadline overrun to TIMEOUT', async () => {
      const { service } = build({ ...IMAGE_CFG, AI_TIMEOUT_MS: 5 }, 'timeout');

      const result = await service.analyzeImage({
        userId,
        image: jpeg('slow to classify'),
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        errorCode: 'TIMEOUT',
      });
    });

    it('maps malformed model JSON to INVALID_MODEL_OUTPUT', async () => {
      const { service } = build(IMAGE_CFG, 'malformed_output');

      const result = await service.analyzeImage({
        userId,
        image: jpeg('unparseable'),
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        errorCode: 'INVALID_MODEL_OUTPUT',
      });
    });

    it('maps model output missing required fields to INVALID_MODEL_OUTPUT', async () => {
      const { service } = build(
        IMAGE_CFG,
        'success',
        JSON.stringify({ category: 'Plumbing' }),
      );

      const result = await service.analyzeImage({
        userId,
        image: jpeg('x'),
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        errorCode: 'INVALID_MODEL_OUTPUT',
      });
    });

    it('returns AI_DISABLED when the feature flag is off', async () => {
      const { service } = build({ AI_ENABLED: 'true' }); // voice flag off

      const result = await service.analyzeVoice({
        userId,
        audio: audio('my sink is leaking'),
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        source: 'voice',
        errorCode: 'AI_DISABLED',
      });
    });

    it('returns AI_DISABLED for combined when vision is off', async () => {
      const { service } = build({
        AI_ENABLED: 'true',
        AI_VOICE_ENABLED: 'true',
      }); // vision flag off

      const result = await service.analyzeCombined({
        userId,
        image: jpeg('air conditioner'),
        audio: audio('the ac is not cooling'),
      });

      expect(result).toMatchObject({
        kind: 'unavailable',
        source: 'image_voice',
        errorCode: 'AI_DISABLED',
      });
    });
  });
});
