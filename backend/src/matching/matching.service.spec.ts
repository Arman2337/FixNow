import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
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

  beforeEach(async () => {
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
      ],
    }).compile();

    service = module.get<MatchingService>(MatchingService);
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
});
