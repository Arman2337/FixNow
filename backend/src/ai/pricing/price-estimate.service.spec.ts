import { NotFoundException } from '@nestjs/common';
import {
  PriceEstimateService,
  PRICE_ESTIMATE_RULES,
} from './price-estimate.service';
import { ServiceCategoryEntity } from '../../services/service-category.entity';

describe('PriceEstimateService', () => {
  const categoryId = '00000000-0000-4000-8000-00000000c7a1';

  const category = (overrides: Partial<ServiceCategoryEntity> = {}) =>
    ({
      id: categoryId,
      isActive: true,
      priceAmount: 49900,
      priceCurrency: 'INR',
      pricing: { amountMinor: 49900, currency: 'INR' },
      ...overrides,
    }) as ServiceCategoryEntity;

  const paidRows = (amountsMinor: number[]) =>
    amountsMinor.map((amount) => ({ amount_minor: amount, currency: 'INR' }));

  const categories = { getActiveCategories: jest.fn() };
  const getRawMany = jest
    .fn<Promise<Array<Record<string, unknown>>>, []>()
    .mockResolvedValue([]);
  const queryBuilder = {
    innerJoin: () => queryBuilder,
    where: () => queryBuilder,
    andWhere: () => queryBuilder,
    orderBy: () => queryBuilder,
    take: () => queryBuilder,
    select: () => queryBuilder,
    addSelect: () => queryBuilder,
    getRawMany: (args?: unknown) => getRawMany(args),
  };
  const dataSource = {
    getRepository: () => ({ createQueryBuilder: () => queryBuilder }),
  };
  const service = new PriceEstimateService(
    categories as never,
    dataSource as never,
  );

  beforeEach(() => jest.clearAllMocks());

  it('rejects unknown or inactive categories with a safe error', async () => {
    categories.getActiveCategories.mockResolvedValue([]);
    await expect(service.estimate(categoryId)).rejects.toThrow(
      NotFoundException,
    );
  });

  it('anchors on the published standard price when history is thin', async () => {
    categories.getActiveCategories.mockResolvedValue([category()]);
    await expect(service.estimate(categoryId)).resolves.toEqual(
      expect.objectContaining({
        kind: 'ESTIMATE',
        basis: 'PUBLISHED',
        currency: 'INR',
        minAmountMinor: 49900,
        maxAmountMinor: 49900,
        typicalAmountMinor: 49900,
        sampleSize: null,
        advisoryNotice: PRICE_ESTIMATE_RULES.advisoryNotice,
      }),
    );
  });

  it('widens to the observed band once enough paid orders exist', async () => {
    categories.getActiveCategories.mockResolvedValue([category()]);
    getRawMany.mockResolvedValue(paidRows([44900, 49900, 49900, 52900, 54900]));
    const result = await service.estimate(categoryId);
    expect(result).toEqual({
      kind: 'ESTIMATE',
      serviceCategoryId: categoryId,
      currency: 'INR',
      minAmountMinor: 44900,
      maxAmountMinor: 54900,
      typicalAmountMinor: 49900,
      basis: 'OBSERVED',
      sampleSize: 5,
      explanation:
        'Typical range across 5 completed FixNow bookings in this category.',
      advisoryNotice: PRICE_ESTIMATE_RULES.advisoryNotice,
    });
  });

  it('abstains honestly for price-on-request categories without history', async () => {
    categories.getActiveCategories.mockResolvedValue([
      category({
        priceAmount: null,
        priceCurrency: null,
        pricing: undefined,
      }),
    ]);
    getRawMany.mockResolvedValue([]);
    const result = await service.estimate(categoryId);
    expect(result.kind).toBe('PRICE_ON_REQUEST');
    if (result.kind === 'PRICE_ON_REQUEST') {
      expect(typeof result.explanation).toBe('string');
    }
  });
});
