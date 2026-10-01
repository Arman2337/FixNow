import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { MatchingService } from './matching.service';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { AccountStatus } from '../users/account-status';
import { ProviderAvailabilityStatus } from '../../../shared/provider-availability.types';
import type { SelectQueryBuilder } from 'typeorm';

describe('MatchingService', () => {
  let service: MatchingService;
  let mockQueryBuilder: jest.Mocked<SelectQueryBuilder<ProviderProfileEntity>>;
  let innerJoinMock: jest.Mock;
  let whereMock: jest.Mock;
  let andWhereMock: jest.Mock;
  let orderByMock: jest.Mock;
  let addOrderByMock: jest.Mock;
  let limitMock: jest.Mock;

  const build = async (config: Record<string, string> = {}) => {
    innerJoinMock = jest.fn().mockReturnThis();
    whereMock = jest.fn().mockReturnThis();
    andWhereMock = jest.fn().mockReturnThis();
    orderByMock = jest.fn().mockReturnThis();
    addOrderByMock = jest.fn().mockReturnThis();
    limitMock = jest.fn().mockReturnThis();
    mockQueryBuilder = {
      innerJoin: innerJoinMock,
      where: whereMock,
      andWhere: andWhereMock,
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      orderBy: orderByMock,
      addOrderBy: addOrderByMock,
      limit: limitMock,
      getRawMany: jest.fn(),
      getCount: jest.fn(),
    } as unknown as jest.Mocked<SelectQueryBuilder<ProviderProfileEntity>>;

    const mockRepository = {
      createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MatchingService,
        {
          provide: getRepositoryToken(ProviderProfileEntity),
          useValue: mockRepository,
        },
        {
          // BUG-016: the staleness bound is configurable, so the test can pin
          // it rather than depending on the wall clock.
          provide: ConfigService,
          useValue: { get: (key: string) => config[key] },
        },
      ],
    }).compile();

    service = module.get<MatchingService>(MatchingService);
  };

  beforeEach(async () => {
    await build();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('findEligibleProviders', () => {
    it('should build query and return mapped providers', async () => {
      const mockRawResults = [
        { providerId: 'provider-1', distanceKm: '2.5' },
        { providerId: 'provider-2', distanceKm: '5.1' },
      ];

      mockQueryBuilder.getRawMany.mockResolvedValue(mockRawResults);

      const result = await service.findEligibleProviders(
        40.7128,
        -74.006,
        'category-id',
        10,
      );

      expect(innerJoinMock).toHaveBeenCalledTimes(4);
      expect(whereMock).toHaveBeenCalledWith('user.status = :accountStatus', {
        accountStatus: AccountStatus.Active,
      });
      expect(andWhereMock).toHaveBeenCalledWith(
        'availability.status = :availStatus',
        { availStatus: ProviderAvailabilityStatus.Online },
      );
      expect(andWhereMock).toHaveBeenCalledWith(
        'skill.service_category_id = :categoryId',
        { categoryId: 'category-id' },
      );
      expect(andWhereMock).toHaveBeenCalledWith(
        'skill.is_verified = :isVerified',
        { isVerified: true },
      );
      expect(andWhereMock).toHaveBeenCalledWith(
        expect.stringContaining('<= profile.serviceRadiusKm'),
        { lat: 40.7128, lng: -74.006 },
      );

      expect(orderByMock).toHaveBeenCalledWith('distanceKm', 'ASC');
      expect(addOrderByMock).toHaveBeenCalledWith('profile.userId', 'ASC');
      expect(limitMock).toHaveBeenCalledWith(10);

      expect(result).toEqual([
        { providerId: 'provider-1', distanceKm: 2.5 },
        { providerId: 'provider-2', distanceKm: 5.1 },
      ]);
    });
  });

  // BUG-007: eligibility must not depend on a provider's rank in a
  // distance-ordered shortlist, so this path must never order or limit.
  describe('isProviderEligible', () => {
    it('reports a provider with a matching row as eligible', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(1);

      const eligible = await service.isProviderEligible(
        'provider-1',
        17.385,
        78.4867,
        'category-1',
      );

      expect(eligible).toBe(true);
    });

    it('reports a provider with no matching row as ineligible', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(0);

      const eligible = await service.isProviderEligible(
        'provider-9',
        17.385,
        78.4867,
        'category-1',
      );

      expect(eligible).toBe(false);
    });

    it('never applies a LIMIT or an ORDER BY', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(1);

      await service.isProviderEligible(
        'provider-1',
        17.385,
        78.4867,
        'category-1',
      );

      // A limit or ordering here is exactly what made the old check rank-based.
      expect(limitMock).not.toHaveBeenCalled();
      expect(orderByMock).not.toHaveBeenCalled();
      expect(addOrderByMock).not.toHaveBeenCalled();
    });

    it('scopes the query to the provider being judged and keeps the same predicate', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(1);

      await service.isProviderEligible(
        'provider-7',
        17.385,
        78.4867,
        'category-1',
      );

      // The provider filter is an additional predicate on the shared builder, not
      // a replacement for it - which is the point: the four public methods differ
      // only in what they add, so they cannot drift apart.
      const whereCalls = whereMock.mock.calls as [
        string,
        Record<string, unknown>,
      ][];
      expect(whereCalls[0][0]).toBe('user.status = :accountStatus');

      const andWhereCalls = andWhereMock.mock.calls as [
        string,
        Record<string, unknown>,
      ][];
      expect(
        andWhereCalls.some(
          ([sql, params]) =>
            sql === 'profile.user_id = :providerId' &&
            (params as { providerId: string }).providerId === 'provider-7',
        ),
      ).toBe(true);

      const predicates = andWhereCalls.map(([sql]) => String(sql).trim());
      expect(
        predicates.some((p) => p.includes('skill.is_verified = :isVerified')),
      ).toBe(true);
      expect(
        predicates.some((p) =>
          p.includes('availability.status = :availStatus'),
        ),
      ).toBe(true);
      expect(
        predicates.some((p) =>
          p.includes('skill.service_category_id = :categoryId'),
        ),
      ).toBe(true);
    });
  });

  // BUG-004: the old code looked for the asking provider inside a top-50
  // fan-out, so an eligible provider outside the nearest 50 was dropped from
  // their own list of available work.
  describe('findProviderDistance', () => {
    it('returns the distance for an eligible provider', async () => {
      mockQueryBuilder.getRawMany.mockResolvedValue([{ distanceKm: '3.25' }]);

      const distance = await service.findProviderDistance(
        'provider-1',
        17.385,
        78.4867,
        'category-1',
      );

      expect(distance).toBe(3.25);
    });

    it('returns null when the provider has no matching row', async () => {
      mockQueryBuilder.getRawMany.mockResolvedValue([]);

      const distance = await service.findProviderDistance(
        'provider-9',
        17.385,
        78.4867,
        'category-1',
      );

      expect(distance).toBeNull();
    });

    it('never orders by, so the answer cannot depend on rank', async () => {
      mockQueryBuilder.getRawMany.mockResolvedValue([]);

      await service.findProviderDistance(
        'provider-1',
        17.385,
        78.4867,
        'category-1',
      );

      expect(orderByMock).not.toHaveBeenCalled();
      expect(addOrderByMock).not.toHaveBeenCalled();
      // LIMIT 1 caps duplicate skill rows, not competing candidates.
      expect(limitMock).toHaveBeenCalledWith(1);
    });
  });

  // BUG-014: the zero-provider case is the most common failure mode in a
  // marketplace launch, and it was unexpressible - nothing could answer "is
  // there any supply here", so a booking in an empty city sat in REQUESTED
  // forever behind a spinner.
  describe('countEligibleProviders', () => {
    it('counts supply without ordering or limiting it', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(7);

      const supply = await service.countEligibleProviders(
        17.385,
        78.4867,
        'category-1',
      );

      expect(supply).toBe(7);
      // A LIMIT here would answer "is the shortlist non-empty" rather than
      // "is anyone available", which is a different and much weaker question.
      expect(limitMock).not.toHaveBeenCalled();
      expect(orderByMock).not.toHaveBeenCalled();
    });

    it('reports zero rather than throwing when nobody is available', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(0);
      await expect(
        service.countEligibleProviders(17.385, 78.4867, 'category-1'),
      ).resolves.toBe(0);
    });

    it('applies the same eligibility predicate as the shortlist', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(1);
      await service.countEligibleProviders(17.385, 78.4867, 'category-1');

      // Account status is the anchor predicate; everything else narrows it.
      const whereCalls = whereMock.mock.calls as [string][];
      expect(
        whereCalls.some(([sql]) =>
          sql.includes('user.status = :accountStatus'),
        ),
      ).toBe(true);

      const predicates = (andWhereMock.mock.calls as [string][]).map((call) =>
        String(call[0]).trim(),
      );
      for (const expected of [
        'availability.status = :availStatus',
        'skill.is_verified = :isVerified',
        'skill.service_category_id = :categoryId',
        'category.is_active = :categoryActive',
      ]) {
        expect(predicates.some((p) => p.includes(expected))).toBe(true);
      }
    });
  });

  // BUG-016: a base location is a home base set weekly, not a live position, so
  // the fix is a staleness bound rather than mandatory live GPS. Without the
  // bound, a profile pinned eight months ago ranked identically to one set a
  // second ago.
  describe('base location freshness (BUG-016)', () => {
    const freshnessPredicate = () =>
      (andWhereMock.mock.calls as [string, Record<string, unknown>][]).find(
        ([sql]) => String(sql).includes('baseLocationUpdatedAt'),
      );

    it('excludes a profile whose base location is older than the bound', async () => {
      await build({ PROVIDER_MAX_LOCATION_AGE_DAYS: '7' });
      mockQueryBuilder.getCount.mockResolvedValue(0);

      await service.countEligibleProviders(17.385, 78.4867, 'category-1');

      const predicate = freshnessPredicate();
      expect(predicate).toBeDefined();
      const floor = predicate![1].freshnessFloor as Date;
      const ageDays = (Date.now() - floor.getTime()) / 86_400_000;
      expect(ageDays).toBeGreaterThan(6.9);
      expect(ageDays).toBeLessThan(7.1);
    });

    it('applies the same freshness bound to every public predicate', async () => {
      mockQueryBuilder.getCount.mockResolvedValue(1);
      await service.isProviderEligible('p1', 17.385, 78.4867, 'category-1');
      expect(freshnessPredicate()).toBeDefined();

      andWhereMock.mockClear();
      mockQueryBuilder.getRawMany.mockResolvedValue([]);
      await service.findProviderDistance('p1', 17.385, 78.4867, 'category-1');
      expect(freshnessPredicate()).toBeDefined();

      andWhereMock.mockClear();
      mockQueryBuilder.getRawMany.mockResolvedValue([]);
      await service.findEligibleProviders(17.385, 78.4867, 'category-1');
      expect(freshnessPredicate()).toBeDefined();
    });

    it('defaults to seven days when the bound is not configured', () => {
      expect(service.maxLocationAgeDays).toBe(7);
    });

    it('rejects a nonsensical bound rather than trusting it', async () => {
      await build({ PROVIDER_MAX_LOCATION_AGE_DAYS: '0' });
      expect(service.maxLocationAgeDays).toBe(7);
    });
  });
});
