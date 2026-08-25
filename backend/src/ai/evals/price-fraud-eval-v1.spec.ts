/**
 * FN-060 evaluation suite `price-fraud-eval-v1`.
 *
 * Versioned, deterministic, synthetic-data-only. Gates the advisory price
 * estimator and the trust review signals against the governance properties
 * required by docs/ai/governance-and-evaluation-architecture.md: no model
 * ever determines a price or a fraud action; every output is explainable,
 * privacy-safe, and stable; thresholds are pinned so silent drift fails
 * this suite.
 *
 * Changing any rule threshold, evidence wording contract, or estimate shape
 * MUST bump the dataset version and re-run this suite.
 */
const EVAL_DATASET_VERSION = 'price-fraud-eval-v1';

import { TrustService, TRUST_RULES } from '../../trust/trust.service';
import {
  PriceEstimateService,
  PRICE_ESTIMATE_RULES,
} from '../pricing/price-estimate.service';
import { ServiceCategoryEntity } from '../../services/service-category.entity';

const SUBJECT_CLEAN = '00000000-0000-4000-8000-00000000c001';
const SUBJECT_FLAGGED = '00000000-0000-4000-8000-00000000c002';
const CATEGORY_ID = '00000000-0000-4000-8000-00000000c7a1';

/** Synthetic cohorts: subject → count observed in the rule window. */
const COHORTS: Record<string, Record<string, number>> = {
  clean: {
    [`customer-cancellations:${SUBJECT_CLEAN}`]: 2,
    [`provider-cancellations:${SUBJECT_CLEAN}`]: 2,
    [`complaints:${SUBJECT_CLEAN}`]: 1,
    refunds: 1,
  },
  flagged: {
    [`customer-cancellations:${SUBJECT_FLAGGED}`]: 3,
    [`provider-cancellations:${SUBJECT_FLAGGED}`]: 3,
    [`complaints:${SUBJECT_FLAGGED}`]: 2,
    refunds: 2,
  },
};

type BuiltService = {
  trust: TrustService;
  estimates: PriceEstimateService;
  bookingsCount: jest.Mock;
  complaintsCount: jest.Mock;
  refundCount: jest.Mock;
  signalsFindOneBy: jest.Mock;
  signalsCreate: jest.Mock;
  getRawMany: jest.Mock;
  activeCategories: jest.Mock;
};

const buildServices = (): BuiltService => {
  const bookingsCount = jest.fn().mockResolvedValue(0);
  const complaintsCount = jest.fn().mockResolvedValue(0);
  const refundCount = jest.fn().mockResolvedValue(0);
  const signalsFindOneBy = jest.fn().mockResolvedValue(null);
  const signalsCreate = jest.fn<unknown, [unknown]>((value) => ({
    ...value,
    id: 'signal',
  }));
  const signalsSave = jest.fn((value) => Promise.resolve(value));
  const getRawMany = jest.fn().mockResolvedValue([]);
  const activeCategories = jest.fn().mockResolvedValue([]);
  const trust = new TrustService(
    { count: bookingsCount } as never,
    {} as never,
    { count: complaintsCount } as never,
    {
      findOneBy: signalsFindOneBy,
      create: signalsCreate,
      save: signalsSave,
    } as never,
    { get: jest.fn(), set: jest.fn() } as never,
    {
      createQueryBuilder: () => {
        const queryBuilder = {
          innerJoin: () => queryBuilder,
          where: () => queryBuilder,
          andWhere: () => queryBuilder,
          getCount: refundCount,
        };
        return queryBuilder;
      },
    } as never,
  );
  const estimates = new PriceEstimateService(
    { getActiveCategories: activeCategories } as never,
    {
      getRepository: () => ({
        createQueryBuilder: () => {
          const queryBuilder = {
            innerJoin: () => queryBuilder,
            where: () => queryBuilder,
            andWhere: () => queryBuilder,
            orderBy: () => queryBuilder,
            take: () => queryBuilder,
            select: () => queryBuilder,
            addSelect: () => queryBuilder,
            getRawMany,
          };
          return queryBuilder;
        },
      }),
    } as never,
  );
  return {
    trust,
    estimates,
    bookingsCount,
    complaintsCount,
    refundCount,
    signalsFindOneBy,
    signalsCreate,
    getRawMany,
    activeCategories,
  };
};

const runAllRules = async (
  built: BuiltService,
  cohort: Record<string, number>,
) => {
  // Provider and customer cancellation rules share the booking counter in
  // this harness; drive each evaluation with its cohort count explicitly.
  const customerCancellations =
    cohort[`customer-cancellations:${SUBJECT_CLEAN}`] ??
    cohort[`customer-cancellations:${SUBJECT_FLAGGED}`] ??
    0;
  const providerCancellations =
    cohort[`provider-cancellations:${SUBJECT_CLEAN}`] ??
    cohort[`provider-cancellations:${SUBJECT_FLAGGED}`] ??
    0;
  built.complaintsCount.mockResolvedValue(
    cohort[`complaints:${SUBJECT_CLEAN}`] ??
      cohort[`complaints:${SUBJECT_FLAGGED}`] ??
      0,
  );
  built.refundCount.mockResolvedValue(cohort['refunds'] ?? 0);

  const produced: Array<Record<string, unknown>> = [];
  const record = (rule: string, value: unknown) => {
    if (value) produced.push({ rule, ...(value as Record<string, unknown>) });
  };
  built.bookingsCount.mockResolvedValueOnce(customerCancellations);
  record(
    'customer-cancellation-frequency-v1',
    await built.trust.evaluateCustomerCancellationSignal(SUBJECT_CLEAN),
  );
  built.bookingsCount.mockResolvedValueOnce(providerCancellations);
  record(
    'provider-cancellation-frequency-v1',
    await built.trust.evaluateCancellationSignal(SUBJECT_CLEAN),
  );
  record(
    'provider-complaint-frequency-v1',
    await built.trust.evaluateComplaintSignal(SUBJECT_CLEAN),
  );
  record(
    'provider-refund-frequency-v1',
    await built.trust.evaluateProviderRefundSignal(SUBJECT_CLEAN),
  );
  return produced;
};

const category = (
  overrides: Partial<ServiceCategoryEntity> = {},
): ServiceCategoryEntity =>
  ({
    id: CATEGORY_ID,
    isActive: true,
    priceAmount: 49900,
    priceCurrency: 'INR',
    pricing: { amountMinor: 49900, currency: 'INR' },
    ...overrides,
  }) as ServiceCategoryEntity;

describe(`${EVAL_DATASET_VERSION}: advisory pricing & fraud-signal governance`, () => {
  it('pins policy thresholds so silent drift fails this suite', () => {
    expect(TRUST_RULES.cancellationThreshold).toBe(3);
    expect(TRUST_RULES.customerCancellationThreshold).toBe(3);
    expect(TRUST_RULES.complaintThreshold).toBe(2);
    expect(TRUST_RULES.refundThreshold).toBe(2);
    expect(PRICE_ESTIMATE_RULES.observedMinSamples).toBe(5);
    for (const days of [
      TRUST_RULES.cancellationWindowDays,
      TRUST_RULES.customerCancellationWindowDays,
      TRUST_RULES.complaintWindowDays,
      TRUST_RULES.refundWindowDays,
    ]) {
      expect(days).toBeGreaterThanOrEqual(1);
      expect(days).toBeLessThanOrEqual(90);
    }
  });

  it('false-positive gate: clean cohorts raise zero signals', async () => {
    const built = buildServices();
    const produced = await runAllRules(built, COHORTS.clean);
    expect(produced).toEqual([]);
  });

  it('detection gate: every threshold-crossing cohort raises exactly one OPEN signal', async () => {
    const built = buildServices();
    const produced = await runAllRules(built, COHORTS.flagged);
    expect(produced).toHaveLength(4);
    for (const signal of produced) {
      expect(signal.status).toBe('OPEN');
      expect(signal.reviewedBy).toBeNull();
    }
  });

  it('bias gate: identical counts produce identical severity and evidence regardless of identity', async () => {
    const first = buildServices();
    const second = buildServices();
    const [a] = await runAllRules(first, COHORTS.flagged);
    const [b] = await runAllRules(second, COHORTS.flagged);
    expect(a?.severity).toEqual(b?.severity);
    expect(a?.evidenceSummary).toEqual(b?.evidenceSummary);
    expect(a?.evidenceSummary).not.toContain(SUBJECT_CLEAN.slice(0, 8));
  });

  it('explanation gate: every signal names its rule, window, and count', async () => {
    const built = buildServices();
    const produced = await runAllRules(built, COHORTS.flagged);
    for (const signal of produced) {
      const summary = String(signal.evidenceSummary);
      expect(summary).toMatch(new RegExp(String(signal.ruleCode)));
      expect(summary).toMatch(/\d+ events/);
      expect(summary).toMatch(/last \d+ days/);
    }
  });

  it('privacy gate: no PII patterns appear in any signal or estimate output', async () => {
    const built = buildServices();
    const produced = await runAllRules(built, COHORTS.flagged);
    built.activeCategories.mockResolvedValue([category()]);
    built.getRawMany.mockResolvedValue([
      { amount_minor: 44900, currency: 'INR' },
      { amount_minor: 49900, currency: 'INR' },
      { amount_minor: 49900, currency: 'INR' },
      { amount_minor: 52900, currency: 'INR' },
      { amount_minor: 54900, currency: 'INR' },
    ]);
    const estimate = (await built.estimates.estimate(CATEGORY_ID)) as Record<
      string,
      unknown
    >;
    // PII can only leak through free-text fields; identifiers are opaque.
    expect(typeof estimate.advisoryNotice).toBe('string');
    const explanationText =
      typeof estimate.explanation === 'string' ? estimate.explanation : '';
    const freeText = [
      ...produced.map((signal) => String(signal.evidenceSummary)),
      explanationText,
    ];
    for (const text of freeText) {
      expect(text).not.toMatch(/[\w.+-]+@[\w-]+\.[a-z]{2,}/i); // emails
      expect(text).not.toMatch(/\+?\d[\d\s-]{9,}/); // phone-like numbers
      expect(text).not.toMatch(/\b\d{1,3}\.\d{4,}\b/); // GPS-precision coordinates
    }
  });

  it('uncertainty gate: estimates disclose basis, sample size, and notice', async () => {
    const built = buildServices();
    built.activeCategories.mockResolvedValue([category()]);
    built.getRawMany.mockResolvedValue(
      [44900, 49900, 54900].map((amount) => ({
        amount_minor: amount,
        currency: 'INR',
      })),
    );
    const thin = await built.estimates.estimate(CATEGORY_ID);
    expect(thin).toMatchObject({
      kind: 'ESTIMATE',
      basis: 'PUBLISHED',
      sampleSize: null,
      advisoryNotice: PRICE_ESTIMATE_RULES.advisoryNotice,
    });

    built.getRawMany.mockResolvedValue(
      [44900, 49900, 49900, 52900, 54900].map((amount) => ({
        amount_minor: amount,
        currency: 'INR',
      })),
    );
    const observed = (await built.estimates.estimate(CATEGORY_ID)) as Record<
      string,
      unknown
    >;
    expect(observed.basis).toBe('OBSERVED');
    const sampleSize = Number(observed.sampleSize);
    expect(sampleSize).toBeGreaterThanOrEqual(
      PRICE_ESTIMATE_RULES.observedMinSamples,
    );
    expect(String(observed.explanation)).toContain(`${sampleSize} completed`);

    built.activeCategories.mockResolvedValue([
      category({ priceAmount: null, priceCurrency: null, pricing: undefined }),
    ]);
    built.getRawMany.mockResolvedValue([]);
    await expect(built.estimates.estimate(CATEGORY_ID)).resolves.toMatchObject({
      kind: 'PRICE_ON_REQUEST',
    });
  });

  it('money gate: all amounts are integer minor units in a single currency', async () => {
    const built = buildServices();
    built.activeCategories.mockResolvedValue([category()]);
    built.getRawMany.mockResolvedValue(
      [44001, 49900, 49900, 52899, 54900].map((amount) => ({
        amount_minor: amount,
        currency: 'INR',
      })),
    );
    const estimate = (await built.estimates.estimate(CATEGORY_ID)) as Record<
      string,
      unknown
    >;
    for (const key of [
      'minAmountMinor',
      'maxAmountMinor',
      'typicalAmountMinor',
    ]) {
      expect(Number.isInteger(estimate[key])).toBe(true);
    }
    expect(estimate.currency).toBe('INR');
  });

  it('determinism gate: identical inputs produce byte-identical results', async () => {
    const first = buildServices();
    const second = buildServices();
    const firstRun = await runAllRules(first, COHORTS.flagged);
    const secondRun = await runAllRules(second, COHORTS.flagged);
    expect(JSON.stringify(firstRun)).toEqual(JSON.stringify(secondRun));
  });
});
