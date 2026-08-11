/* Jest repository/service mocks are intentionally asserted as detached functions. */
/* eslint-disable @typescript-eslint/unbound-method */
import { Test, TestingModule } from '@nestjs/testing';
import { ProviderSkillsController } from './provider-skills.controller';
import { ProviderSkillsService } from './provider-skills.service';
import {
  CreateProviderSkillDto,
  UpdateProviderSkillDto,
  VerifyProviderSkillDto,
} from './provider-skills.dto';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

describe('ProviderSkillsController', () => {
  let controller: ProviderSkillsController;
  let service: jest.Mocked<ProviderSkillsService>;

  const mockSkill = {
    id: 'skill-id',
    userId: 'user-id',
    serviceCategoryId: 'category-id',
    yearsExperience: 5,
    hourlyRateCents: 5000,
    visitFeeCents: 2500,
    description: 'Experienced plumber',
    isVerified: false,
    verificationNotes: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockRequest = {
    authorizationPrincipal: {
      userId: 'user-id',
      sessionId: 'session-id',
      roles: ['provider_applicant'],
    },
  } as AuthorizedRequest;

  beforeEach(async () => {
    const mockService = {
      findByUserId: jest.fn(),
      findById: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      verifySkill: jest.fn(),
      findVerifiedSkillsByCategory: jest.fn(),
      getProviderSkillsCount: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ProviderSkillsController],
      providers: [
        {
          provide: ProviderSkillsService,
          useValue: mockService,
        },
      ],
    }).compile();

    controller = module.get<ProviderSkillsController>(ProviderSkillsController);
    service = module.get(ProviderSkillsService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getMySkills', () => {
    it('should return user skills', async () => {
      const query = { isVerified: true };
      service.findByUserId.mockResolvedValue([mockSkill]);

      const result = await controller.getMySkills(mockRequest, query);

      expect(service.findByUserId).toHaveBeenCalledWith('user-id', query);
      expect(result).toEqual([mockSkill]);
    });
  });

  describe('getMySkillsCount', () => {
    it('should return skills count', async () => {
      const countResult = { total: 5, verified: 3 };
      service.getProviderSkillsCount.mockResolvedValue(countResult);

      const result = await controller.getMySkillsCount(mockRequest);

      expect(service.getProviderSkillsCount).toHaveBeenCalledWith('user-id');
      expect(result).toEqual(countResult);
    });
  });

  describe('getProviderSkills', () => {
    it('should return skills for specific provider', async () => {
      const query = { isVerified: true };
      service.findByUserId.mockResolvedValue([mockSkill]);

      const result = await controller.getProviderSkills('provider-id', query);

      expect(service.findByUserId).toHaveBeenCalledWith('provider-id', query);
      expect(result).toEqual([mockSkill]);
    });
  });

  describe('getVerifiedSkillsByCategory', () => {
    it('should return verified skills for category', async () => {
      service.findVerifiedSkillsByCategory.mockResolvedValue([mockSkill]);

      const result =
        await controller.getVerifiedSkillsByCategory('category-id');

      expect(service.findVerifiedSkillsByCategory).toHaveBeenCalledWith(
        'category-id',
      );
      expect(result).toEqual([mockSkill]);
    });
  });

  describe('findById', () => {
    it('should return skill by ID', async () => {
      service.findById.mockResolvedValue(mockSkill);

      const result = await controller.findById('skill-id');

      expect(service.findById).toHaveBeenCalledWith('skill-id');
      expect(result).toEqual(mockSkill);
    });
  });

  describe('create', () => {
    it('should create new skill', async () => {
      const createDto: CreateProviderSkillDto = {
        serviceCategoryId: 'category-id',
        yearsExperience: 5,
        hourlyRateCents: 5000,
      };
      service.create.mockResolvedValue(mockSkill);

      const result = await controller.create(mockRequest, createDto);

      expect(service.create).toHaveBeenCalledWith('user-id', createDto);
      expect(result).toEqual(mockSkill);
    });
  });

  describe('update', () => {
    it('should update skill', async () => {
      const updateDto: UpdateProviderSkillDto = {
        yearsExperience: 7,
        description: 'Updated description',
      };
      service.update.mockResolvedValue({ ...mockSkill, ...updateDto });

      const result = await controller.update(
        'skill-id',
        mockRequest,
        updateDto,
      );

      expect(service.update).toHaveBeenCalledWith(
        'skill-id',
        'user-id',
        updateDto,
        false,
      );
      expect(result).toEqual(expect.objectContaining(updateDto));
    });

    it('does not elevate an owner endpoint from request role claims', async () => {
      const adminRequest = {
        authorizationPrincipal: {
          userId: 'admin-id',
          sessionId: 'session-id',
          roles: ['operations_administrator'],
        },
      } as AuthorizedRequest;

      const updateDto: UpdateProviderSkillDto = { isVerified: true };
      service.update.mockResolvedValue({ ...mockSkill, ...updateDto });

      await controller.update('skill-id', adminRequest, updateDto);

      expect(service.update).toHaveBeenCalledWith(
        'skill-id',
        'admin-id',
        updateDto,
        false,
      );
    });
  });

  describe('verifySkill', () => {
    it('should verify skill', async () => {
      const verifyDto: VerifyProviderSkillDto = {
        isVerified: true,
        verificationNotes: 'Verified successfully',
      };
      service.verifySkill.mockResolvedValue({ ...mockSkill, ...verifyDto });

      const result = await controller.verifySkill('skill-id', verifyDto);

      expect(service.verifySkill).toHaveBeenCalledWith(
        'skill-id',
        true,
        'Verified successfully',
      );
      expect(result).toEqual(expect.objectContaining(verifyDto));
    });
  });

  describe('delete', () => {
    it('should delete skill', async () => {
      service.delete.mockResolvedValue(undefined);

      await controller.delete('skill-id', mockRequest);

      expect(service.delete).toHaveBeenCalledWith('skill-id', 'user-id', false);
    });

    it('does not elevate delete from request role claims', async () => {
      const adminRequest = {
        authorizationPrincipal: {
          userId: 'admin-id',
          sessionId: 'session-id',
          roles: ['operations_administrator'],
        },
      } as AuthorizedRequest;

      service.delete.mockResolvedValue(undefined);

      await controller.delete('skill-id', adminRequest);

      expect(service.delete).toHaveBeenCalledWith(
        'skill-id',
        'admin-id',
        false,
      );
    });
  });
});
