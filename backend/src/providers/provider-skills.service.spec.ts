import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { ProviderSkillsService } from './provider-skills.service';
import { ProviderSkillEntity } from './provider-skill.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import {
  CreateProviderSkillDto,
  UpdateProviderSkillDto,
} from './provider-skills.dto';

describe('ProviderSkillsService', () => {
  let service: ProviderSkillsService;
  let skillRepository: jest.Mocked<Repository<ProviderSkillEntity>>;
  let categoryRepository: jest.Mocked<Repository<ServiceCategoryEntity>>;

  const mockSkill: ProviderSkillEntity = {
    id: 'skill-id',
    userId: 'user-id',
    serviceCategoryId: 'category-id',
    yearsExperience: 5,
    hourlyRateCents: 5000,
    visitFeeCents: 2500,
    description: 'Experienced plumber',
    isVerified: false,
    verificationNotes: null,
    user: {} as any,
    serviceCategory: {} as any,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockCategory: ServiceCategoryEntity = {
    id: 'category-id',
    name: 'Plumbing',
    slug: 'plumbing',
    description: 'Plumbing services',
    iconName: 'plumbing',
    displayOrder: 1,
    isActive: true,
    isEmergency: false,
    providerSkills: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    addOrderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn(),
  };

  beforeEach(async () => {
    const mockSkillRepository = {
      createQueryBuilder: jest.fn(() => mockQueryBuilder),
      findOne: jest.fn(),
      create: jest.fn(),
      save: jest.fn(),
      remove: jest.fn(),
      find: jest.fn(),
      count: jest.fn(),
    };

    const mockCategoryRepository = {
      findOne: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProviderSkillsService,
        {
          provide: getRepositoryToken(ProviderSkillEntity),
          useValue: mockSkillRepository,
        },
        {
          provide: getRepositoryToken(ServiceCategoryEntity),
          useValue: mockCategoryRepository,
        },
      ],
    }).compile();

    service = module.get<ProviderSkillsService>(ProviderSkillsService);
    skillRepository = module.get(getRepositoryToken(ProviderSkillEntity));
    categoryRepository = module.get(getRepositoryToken(ServiceCategoryEntity));
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findByUserId', () => {
    it('should return user skills with filters', async () => {
      mockQueryBuilder.getMany.mockResolvedValue([mockSkill]);

      const result = await service.findByUserId('user-id', {
        isVerified: true,
      });

      expect(skillRepository.createQueryBuilder).toHaveBeenCalledWith('skill');
      expect(mockQueryBuilder.leftJoinAndSelect).toHaveBeenCalledWith(
        'skill.serviceCategory',
        'category',
      );
      expect(mockQueryBuilder.where).toHaveBeenCalledWith(
        'skill.userId = :userId',
        { userId: 'user-id' },
      );
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'skill.isVerified = :isVerified',
        { isVerified: true },
      );
      expect(result).toEqual([mockSkill]);
    });
  });

  describe('findById', () => {
    it('should return skill when found', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);

      const result = await service.findById('skill-id');

      expect(skillRepository.findOne).toHaveBeenCalledWith({
        where: { id: 'skill-id' },
        relations: ['user', 'serviceCategory'],
      });
      expect(result).toEqual(mockSkill);
    });

    it('should throw NotFoundException when skill not found', async () => {
      skillRepository.findOne.mockResolvedValue(null);

      await expect(service.findById('non-existent')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('create', () => {
    const createDto: CreateProviderSkillDto = {
      serviceCategoryId: 'category-id',
      yearsExperience: 5,
      hourlyRateCents: 5000,
      visitFeeCents: 2500,
      description: 'Experienced plumber',
    };

    it('should create skill successfully', async () => {
      categoryRepository.findOne.mockResolvedValue(mockCategory);
      skillRepository.findOne.mockResolvedValue(null); // No existing skill
      skillRepository.create.mockReturnValue(mockSkill);
      skillRepository.save.mockResolvedValue(mockSkill);

      const result = await service.create('user-id', createDto);

      expect(categoryRepository.findOne).toHaveBeenCalledWith({
        where: { id: 'category-id', isActive: true },
      });
      expect(skillRepository.findOne).toHaveBeenCalledWith({
        where: { userId: 'user-id', serviceCategoryId: 'category-id' },
      });
      expect(skillRepository.create).toHaveBeenCalledWith({
        ...createDto,
        userId: 'user-id',
        isVerified: false,
      });
      expect(result).toEqual(mockSkill);
    });

    it('should throw BadRequestException for inactive category', async () => {
      categoryRepository.findOne.mockResolvedValue(null);

      await expect(service.create('user-id', createDto)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for duplicate skill', async () => {
      categoryRepository.findOne.mockResolvedValue(mockCategory);
      skillRepository.findOne.mockResolvedValue(mockSkill); // Existing skill

      await expect(service.create('user-id', createDto)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('update', () => {
    const updateDto: UpdateProviderSkillDto = {
      yearsExperience: 7,
      description: 'Updated description',
    };

    it('should update skill successfully for owner', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);
      skillRepository.save.mockResolvedValue({ ...mockSkill, ...updateDto });

      const result = await service.update('skill-id', 'user-id', updateDto);

      expect(skillRepository.save).toHaveBeenCalledWith(
        expect.objectContaining(updateDto),
      );
      expect(result).toEqual(expect.objectContaining(updateDto));
    });

    it('should throw ForbiddenException for non-owner', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);

      await expect(
        service.update('skill-id', 'other-user', updateDto),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should allow admin to update any skill', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);
      const adminUpdate = { ...updateDto, isVerified: true };
      skillRepository.save.mockResolvedValue({ ...mockSkill, ...adminUpdate });

      const result = await service.update(
        'skill-id',
        'other-user',
        adminUpdate,
        true,
      );

      expect(skillRepository.save).toHaveBeenCalledWith(
        expect.objectContaining(adminUpdate),
      );
      expect(result).toEqual(expect.objectContaining(adminUpdate));
    });

    it('should filter out admin-only fields for non-admin users', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);
      const userUpdate = {
        ...updateDto,
        isVerified: true,
        verificationNotes: 'test',
      };
      skillRepository.save.mockResolvedValue({ ...mockSkill, ...updateDto });

      await service.update('skill-id', 'user-id', userUpdate);

      expect(skillRepository.save).toHaveBeenCalledWith(
        expect.not.objectContaining({
          isVerified: true,
          verificationNotes: 'test',
        }),
      );
    });
  });

  describe('delete', () => {
    it('should delete skill successfully for owner', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);

      await service.delete('skill-id', 'user-id');

      expect(skillRepository.remove).toHaveBeenCalledWith(mockSkill);
    });

    it('should throw ForbiddenException for non-owner', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);

      await expect(service.delete('skill-id', 'other-user')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('should allow admin to delete any skill', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);

      await service.delete('skill-id', 'other-user', true);

      expect(skillRepository.remove).toHaveBeenCalledWith(mockSkill);
    });
  });

  describe('verifySkill', () => {
    it('should update skill verification status', async () => {
      skillRepository.findOne.mockResolvedValue(mockSkill);
      const verifiedSkill = {
        ...mockSkill,
        isVerified: true,
        verificationNotes: 'Verified',
      };
      skillRepository.save.mockResolvedValue(verifiedSkill);

      const result = await service.verifySkill('skill-id', true, 'Verified');

      expect(skillRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          isVerified: true,
          verificationNotes: 'Verified',
        }),
      );
      expect(result).toEqual(verifiedSkill);
    });
  });

  describe('findVerifiedSkillsByCategory', () => {
    it('should return verified skills for category', async () => {
      skillRepository.find.mockResolvedValue([mockSkill]);

      const result = await service.findVerifiedSkillsByCategory('category-id');

      expect(skillRepository.find).toHaveBeenCalledWith({
        where: { serviceCategoryId: 'category-id', isVerified: true },
        relations: ['user', 'serviceCategory'],
      });
      expect(result).toEqual([mockSkill]);
    });
  });

  describe('getProviderSkillsCount', () => {
    it('should return total and verified counts', async () => {
      skillRepository.count.mockResolvedValueOnce(10).mockResolvedValueOnce(7);

      const result = await service.getProviderSkillsCount('user-id');

      expect(skillRepository.count).toHaveBeenCalledWith({
        where: { userId: 'user-id' },
      });
      expect(skillRepository.count).toHaveBeenCalledWith({
        where: { userId: 'user-id', isVerified: true },
      });
      expect(result).toEqual({ total: 10, verified: 7 });
    });
  });
});
