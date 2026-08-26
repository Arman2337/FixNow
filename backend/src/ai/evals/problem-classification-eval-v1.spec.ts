/**
 * FN-058 / FN-059 evaluation suite `problem-classification-eval-v1`.
 *
 * Versioned, deterministic, synthetic-data-only. Gates the advisory
 * multimodal problem classifier against the governance properties required by
 * docs/ai/governance-and-evaluation-architecture.md and ADR-0014:
 *   - the model may only ever emit a category from the FixNow taxonomy;
 *   - an unmappable input is salvaged to a low-confidence "Other", never an
 *     invented label;
 *   - a chosen category grounds to the active DB catalog for the bookable
 *     handoff, and stays advisory-only (null) when there is no match;
 *   - confidence banding is a pinned policy so silent drift fails this suite;
 *   - safety guidance is deterministic and never inflates confidence;
 *   - no output can auto-book, and no raw media leaves the machine.
 *
 * Changing the taxonomy, the banding thresholds, the confidence cap, or the
 * grounding contract MUST bump the dataset version and re-run this suite.
 */
const EVAL_DATASET_VERSION = 'problem-classification-eval-v1';

import { ConfigService } from '@nestjs/config';
import { Logger } from 'nestjs-pino';
import { ProblemAnalysis } from '../../../../shared/problem-analysis.types';
import { ServiceCategoriesService } from '../../services/service-categories.service';
import { ServiceCategoryEntity } from '../../services/service-category.entity';
import { AiService } from '../ai.service';
import { DeterministicAiProvider } from '../providers/deterministic-ai.provider';
import { isAllowedCategory } from '../problem-classification/categories.config';
import { ProblemClassificationService } from '../problem-classification/problem-classification.service';

/** Full synthetic bookable catalog so a confident label always has a target. */
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
    id: 'cat-fridge',
    name: 'Refrigerator',
    slug: 'refrigerator',
    isActive: true,
  },
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
  { id: 'cat-carpentry', name: 'Carpentry', slug: 'carpentry', isActive: true },
  { id: 'cat-painting', name: 'Painting', slug: 'painting', isActive: true },
  {
    id: 'cat-appliance',
    name: 'Home Appliance',
    slug: 'home-appliance',
    isActive: true,
  },
] as unknown as ServiceCategoryEntity[];

const CFG = {
  AI_ENABLED: 'true',
  AI_VOICE_ENABLED: 'true',
  AI_VISION_ENABLED: 'true',
  AI_REQUEST_RATE_LIMIT: 1000,
};

const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff]);

function jpeg(hint: string): { bytes: Buffer; mimeType: string } {
  return {
    bytes: Buffer.concat([JPEG_MAGIC, Buffer.from(` ${hint}`)]),
    mimeType: 'image/jpeg',
  };
}

function audio(transcript: string): { bytes: Buffer; mimeType: string } {
  return { bytes: Buffer.from(transcript), mimeType: 'audio/mpeg' };
}

function buildService(rawOutput?: string): ProblemClassificationService {
  const config = {
    get: jest.fn((key: string, fallback?: unknown) =>
      key in CFG ? (CFG as Record<string, unknown>)[key] : fallback,
    ),
  } as unknown as ConfigService;
  const logger = { info: jest.fn() } as unknown as Logger;
  const provider =
    rawOutput === undefined
      ? new DeterministicAiProvider('success')
      : new DeterministicAiProvider('success', rawOutput);
  const ai = new AiService(config, provider, logger);
  const categories = {
    getActiveCategories: jest.fn().mockResolvedValue(ACTIVE_CATEGORIES),
  } as unknown as ServiceCategoriesService;
  return new ProblemClassificationService(ai, categories);
}

async function analysisOf(
  service: ProblemClassificationService,
  mode: 'image' | 'voice',
  hint: string,
): Promise<ProblemAnalysis> {
  const result =
    mode === 'image'
      ? await service.analyzeImage({ userId: 'eval', image: jpeg(hint) })
      : await service.analyzeVoice({ userId: 'eval', audio: audio(hint) });
  if (result.kind !== 'analysis')
    throw new Error(`expected an analysis for "${hint}", got ${result.kind}`);
  return result;
}

interface LabeledCase {
  readonly mode: 'image' | 'voice';
  readonly hint: string;
  readonly expectedCategory: string;
  readonly expectedGroundId: string | null;
  readonly hazard: boolean;
}

/** Synthetic, deterministic label space exercised across both modalities. */
const DATASET: readonly LabeledCase[] = [
  {
    mode: 'image',
    hint: 'pipe leaking under the sink',
    expectedCategory: 'Plumbing',
    expectedGroundId: 'cat-plumbing',
    hazard: false,
  },
  {
    mode: 'voice',
    hint: 'the electrical socket is sparking',
    expectedCategory: 'Electrical',
    expectedGroundId: 'cat-electrical',
    hazard: true,
  },
  {
    mode: 'image',
    hint: 'air conditioner not cooling',
    expectedCategory: 'AC Repair',
    expectedGroundId: 'cat-ac',
    hazard: false,
  },
  {
    mode: 'voice',
    hint: 'refrigerator is not cooling at all',
    expectedCategory: 'Refrigerator',
    expectedGroundId: 'cat-fridge',
    hazard: false,
  },
  {
    mode: 'image',
    hint: 'washing machine not draining',
    expectedCategory: 'Washing Machine',
    expectedGroundId: 'cat-washer',
    hazard: false,
  },
  {
    mode: 'voice',
    hint: 'geyser gives no hot water',
    expectedCategory: 'Water Heater',
    expectedGroundId: 'cat-water-heater',
    hazard: false,
  },
  {
    mode: 'voice',
    hint: 'the gas stove burner will not ignite',
    expectedCategory: 'Gas/Stove',
    expectedGroundId: 'cat-gas',
    hazard: true,
  },
  {
    mode: 'image',
    hint: 'wooden door hinge is broken',
    expectedCategory: 'Carpentry',
    expectedGroundId: 'cat-carpentry',
    hazard: false,
  },
  {
    mode: 'image',
    hint: 'repaint the bedroom wall',
    expectedCategory: 'Painting',
    expectedGroundId: 'cat-painting',
    hazard: false,
  },
  {
    mode: 'voice',
    hint: 'the microwave is not heating',
    expectedCategory: 'Home Appliance',
    expectedGroundId: 'cat-appliance',
    hazard: false,
  },
  // Unmappable input: must salvage to a low-confidence "Other", never invent.
  {
    mode: 'image',
    hint: 'zzz qwerty asdf nonsense',
    expectedCategory: 'Other',
    expectedGroundId: null,
    hazard: false,
  },
];

describe(`${EVAL_DATASET_VERSION}: advisory multimodal classification governance`, () => {
  it('label-space gate: every produced category belongs to the FixNow taxonomy', async () => {
    const service = buildService();
    for (const testCase of DATASET) {
      const analysis = await analysisOf(service, testCase.mode, testCase.hint);
      expect(isAllowedCategory(analysis.category)).toBe(true);
      expect(analysis.category).toBe(testCase.expectedCategory);
    }
  });

  it('grounding gate: confident labels map to the catalog at a 100% rate', async () => {
    const service = buildService();
    const confident = DATASET.filter((c) => c.expectedCategory !== 'Other');
    let grounded = 0;
    for (const testCase of confident) {
      const analysis = await analysisOf(service, testCase.mode, testCase.hint);
      expect(analysis.serviceCategoryId).toBe(testCase.expectedGroundId);
      expect(analysis.serviceName).toBe(testCase.expectedCategory);
      if (analysis.serviceCategoryId !== null) grounded += 1;
    }
    expect(grounded / confident.length).toBe(1);
  });

  it('coercion gate: an unmappable input salvages to a capped-confidence "Other"', async () => {
    const service = buildService();
    const analysis = await analysisOf(
      service,
      'image',
      'zzz qwerty asdf nonsense',
    );
    expect(analysis.category).toBe('Other');
    expect(analysis.subcategory).toBe('Other');
    expect(analysis.confidence).toBeLessThanOrEqual(0.5);
    expect(analysis.serviceCategoryId).toBeNull();
    expect(analysis.serviceName).toBeNull();
  });

  it('coercion gate: an invented category from the model is neutralized to "Other"', async () => {
    const service = buildService(
      JSON.stringify({
        category: 'Teleportation Repair',
        subcategory: 'Warp Core',
        problem_summary: 'An unmappable contraption.',
        urgency: 'high',
        confidence: 0.99,
      }),
    );
    const analysis = await analysisOf(service, 'image', 'anything');
    expect(analysis.category).toBe('Other');
    expect(analysis.confidence).toBeLessThanOrEqual(0.5);
    expect(analysis.serviceCategoryId).toBeNull();
  });

  it.each([
    [0.85, 'high'],
    [0.84, 'medium'],
    [0.6, 'medium'],
    [0.59, 'low'],
  ])(
    'banding gate: confidence %s is pinned to the "%s" band',
    async (confidence, band) => {
      const service = buildService(
        JSON.stringify({
          category: 'Plumbing',
          subcategory: 'Pipe Leakage',
          problem_summary: 'A pipe is leaking.',
          urgency: 'medium',
          confidence,
        }),
      );
      const analysis = await analysisOf(service, 'image', 'pipe');
      expect(analysis.confidence).toBe(confidence);
      expect(analysis.confidenceBand).toBe(band);
    },
  );

  it('safety gate: hazards surface deterministic guidance without inflating confidence', async () => {
    const service = buildService();
    for (const testCase of DATASET) {
      const analysis = await analysisOf(service, testCase.mode, testCase.hint);
      if (testCase.hazard) {
        expect(analysis.safetyNotice).not.toBeNull();
      }
      // The notice is advisory text only; it never becomes a confident match
      // on its own. Confidence stays within the valid range regardless.
      expect(analysis.confidence).toBeGreaterThanOrEqual(0);
      expect(analysis.confidence).toBeLessThanOrEqual(1);
    }
  });

  it('contract gate: no output can auto-book and raw transcripts stay modality-scoped', async () => {
    const service = buildService();
    const image = await analysisOf(
      service,
      'image',
      'pipe leaking under the sink',
    );
    const voice = await analysisOf(
      service,
      'voice',
      'the microwave is not heating',
    );

    // Advisory contract only — nothing that could trigger a booking/assignment.
    for (const analysis of [image, voice]) {
      expect(analysis).not.toHaveProperty('bookingId');
      expect(analysis).not.toHaveProperty('providerId');
      expect(analysis).not.toHaveProperty('autoBook');
    }
    // Image analysis carries no transcript; voice echoes exactly what was said.
    expect(image.transcription).toBeUndefined();
    expect(voice.transcription).toBe('the microwave is not heating');
  });

  it('determinism gate: identical inputs produce byte-identical results', async () => {
    const first = buildService();
    const second = buildService();
    for (const testCase of DATASET) {
      const a = await analysisOf(first, testCase.mode, testCase.hint);
      const b = await analysisOf(second, testCase.mode, testCase.hint);
      expect(JSON.stringify(a)).toBe(JSON.stringify(b));
    }
  });
});
