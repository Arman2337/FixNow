import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { MatchingService } from './matching.service';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { AccountStatus } from '../users/account-status';
import { ProviderAvailabilityStatus } from '../../../shared/provider-availability.types';

describe('MatchingService', () => {
  let service: MatchingService;
  let mockQueryBuilder: any;

  beforeEach(async () => {
    mockQueryBuilder = {
      innerJoin: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      getRawMany: jest.fn(),
    };

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

      const result = await service.findEligibleProviders(40.7128, -74.0060, 'category-id', 10);

      expect(mockQueryBuilder.innerJoin).toHaveBeenCalledTimes(3);
      expect(mockQueryBuilder.where).toHaveBeenCalledWith('user.status = :accountStatus', { accountStatus: AccountStatus.Active });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith('availability.status = :availStatus', { availStatus: ProviderAvailabilityStatus.Online });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith('skill.serviceCategoryId = :categoryId', { categoryId: 'category-id' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith('skill.isVerified = :isVerified', { isVerified: true });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(expect.stringContaining('<= profile.serviceRadiusKm'), { lat: 40.7128, lng: -74.0060 });
      
      expect(mockQueryBuilder.orderBy).toHaveBeenCalledWith('distanceKm', 'ASC');
      expect(mockQueryBuilder.limit).toHaveBeenCalledWith(10);

      expect(result).toEqual([
        { providerId: 'provider-1', distanceKm: 2.5 },
        { providerId: 'provider-2', distanceKm: 5.1 },
      ]);
    });
  });
});
