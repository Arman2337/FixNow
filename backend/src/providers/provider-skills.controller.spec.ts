/* Jest repository/service mocks are intentionally asserted as detached functions. */
/* eslint-disable @typescript-eslint/unbound-method */
import { ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ProviderSkillsController } from './provider-skills.controller';
import { ProviderSkillsService } from './provider-skills.service';
import type { ProviderSkillEntity } from './provider-skill.entity';
import {
  CreateProviderSkillDto,
  UpdateProviderSkillDto,
  VerifyProviderSkillDto,
} from './provider-skills.dto';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  PERMISSIONS,
  PERMISSION_POLICIES,
} from '../common/authorization/permission-policies';
import type { RoleCode } from '../common/authorization/permission-policies';

/** A complete skill row: the entity carries `user` and `serviceCategory`. */
function skillFixture(
  overrides: Partial<ProviderSkillEntity> = {},
): ProviderSkillEntity {
  return {
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
    user: undefined,
    serviceCategory: undefined,
    ...overrides,
  } as ProviderSkillEntity;
}

/** The controller only reads `authorizationPrincipal` off the request. */
function requestWith(userId: string, roles: RoleCode[]): AuthorizedRequest {
  return {
    authorizationPrincipal: { userId, sessionId: 'session-id', roles },
  } as unknown as AuthorizedRequest;
}

describe('ProviderSkillsController', () => {
  let controller: ProviderSkillsController;
  let service: jest.Mocked<ProviderSkillsService>;

  const mockSkill = skillFixture();

  const mockRequest = requestWith('user-id', ['provider_applicant']);

  beforeEach(async () => {
    const mockService = {
      findByUserId: jest.fn(),
      findById: jest.fn(),
      findOwnedById: jest.fn(),
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
    it('scopes the lookup to the calling provider (SEC-002)', async () => {
      service.findOwnedById.mockResolvedValue(mockSkill);

      const result = await controller.findById('skill-id', mockRequest);

      // The caller's id must be part of the lookup, otherwise any provider can
      // read another provider's skill (and the user relation behind it).
      expect(service.findOwnedById).toHaveBeenCalledWith('skill-id', 'user-id');
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
      const adminRequest = requestWith('admin-id', [
        'operations_administrator',
      ]);

      const updateDto: UpdateProviderSkillDto = { isVerified: true };
      // `isAdmin` stays false, so this call still goes down the owner path and
      // must resolve a skill the caller actually owns.
      service.update.mockResolvedValue(
        skillFixture({ userId: 'admin-id', ...updateDto }),
      );

      await controller.update('skill-id', adminRequest, updateDto);

      expect(service.update).toHaveBeenCalledWith(
        'skill-id',
        'admin-id',
        updateDto,
        false,
      );
    });

    it('refuses a skill the caller does not own (SEC-002)', async () => {
      service.update.mockResolvedValue(
        skillFixture({ userId: 'someone-else' }),
      );

      await expect(
        controller.update('skill-id', mockRequest, {
          yearsExperience: 7,
        }),
      ).rejects.toBeInstanceOf(ForbiddenException);
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

      // SEC-002: the principal is handed to the service because `delete`
      // returns nothing, so the owner comparison has to happen inside it.
      expect(service.delete).toHaveBeenCalledWith(
        'skill-id',
        'user-id',
        false,
        mockRequest.authorizationPrincipal,
      );
    });

    it('does not elevate delete from request role claims', async () => {
      const adminRequest = requestWith('admin-id', [
        'operations_administrator',
      ]);

      service.delete.mockResolvedValue(undefined);

      await controller.delete('skill-id', adminRequest);

      expect(service.delete).toHaveBeenCalledWith(
        'skill-id',
        'admin-id',
        false,
        adminRequest.authorizationPrincipal,
      );
    });
  });

  // SEC-002: reading another user's skills is a separate, role-gated route. The
  // policy has no `relationship` clause, so it raises no deferred obligation —
  // and the role list must not quietly widen.
  describe('getProviderSkills cross-user access', () => {
    it('stays on the read-any permission with reviewer-only roles', () => {
      expect(PERMISSION_POLICIES[PERMISSIONS.providerSkillsReadAny]).toEqual({
        roles: [
          'provider_reviewer',
          'service_catalog_manager',
          'operations_administrator',
          'auditor',
        ],
      });
    });

    it('does not give a plain provider read-any', () => {
      expect(
        PERMISSION_POLICIES[PERMISSIONS.providerSkillsReadAny].roles,
      ).not.toContain('verified_provider');
      expect(
        PERMISSION_POLICIES[PERMISSIONS.providerSkillsReadAny].roles,
      ).not.toContain('provider_applicant');
    });
  });
});
