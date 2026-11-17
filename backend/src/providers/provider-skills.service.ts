import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProviderSkillEntity } from './provider-skill.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { ProviderApplicationEntity } from './provider-application.entity';
import { ProviderOnboardingStatus } from './provider-onboarding-status';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import { assertOwnedResource } from '../common/authorization/resource-ownership';
import {
  LIST_ENDPOINT_DEFAULT_LIMIT,
  LIST_ENDPOINT_MAX_LIMIT,
} from '../common/list-pagination.dto';
import {
  CreateProviderSkillDto,
  UpdateProviderSkillDto,
  ProviderSkillQueryDto,
} from './provider-skills.dto';

/**
 * Recorded on skills that were trusted because the provider's own account was
 * already verified, so an auditor can tell "a person checked this" apart from
 * "this followed the account's verification".
 */
export const AUTO_VERIFIED_NOTE =
  'auto-verified: provider account passed identity verification';

@Injectable()
export class ProviderSkillsService {
  constructor(
    @InjectRepository(ProviderSkillEntity)
    private readonly providerSkillRepository: Repository<ProviderSkillEntity>,
    @InjectRepository(ServiceCategoryEntity)
    private readonly serviceCategoryRepository: Repository<ServiceCategoryEntity>,
    @InjectRepository(ProviderApplicationEntity)
    private readonly applicationRepository: Repository<ProviderApplicationEntity>,
  ) {}

  async findByUserId(
    userId: string,
    query?: ProviderSkillQueryDto,
  ): Promise<ProviderSkillEntity[]> {
    const queryBuilder = this.providerSkillRepository
      .createQueryBuilder('skill')
      .leftJoinAndSelect('skill.serviceCategory', 'category')
      .where('skill.userId = :userId', { userId });

    if (query?.isVerified !== undefined) {
      queryBuilder.andWhere('skill.isVerified = :isVerified', {
        isVerified: query.isVerified,
      });
    }

    if (query?.serviceCategoryId) {
      queryBuilder.andWhere('skill.serviceCategoryId = :serviceCategoryId', {
        serviceCategoryId: query.serviceCategoryId,
      });
    }

    queryBuilder
      .orderBy('category.displayOrder', 'ASC')
      .addOrderBy('category.name', 'ASC')
      // API-003: bounded in the query. A provider's skill list is small today,
      // but it is one row per provider per category, so the count grows with
      // both the catalogue and the provider's own ambitions — and this route is
      // reachable by anyone holding a provider credential.
      .take(
        Math.min(
          query?.limit ?? LIST_ENDPOINT_DEFAULT_LIMIT,
          LIST_ENDPOINT_MAX_LIMIT,
        ),
      );

    return queryBuilder.getMany();
  }

  /**
   * Loads a single skill for its owner.
   *
   * SEC-002: this used to be a bare `findOne({ where: { id } })` that also
   * eagerly loaded the owning `UserEntity`, and the controller returned that
   * entity straight to the client. Any provider could read another provider's
   * phone number, account status and status-reason text by enumerating skill
   * ids. Ownership is now part of the query, and the owning user relation is
   * no longer loaded at all.
   */
  async findOwnedById(
    id: string,
    userId: string,
  ): Promise<ProviderSkillEntity> {
    const skill = await this.providerSkillRepository.findOne({
      where: { id, userId },
      relations: { serviceCategory: true },
    });

    // Scoping by owner means a foreign id is simply absent, so this is a 404
    // rather than a 403: a 403 would confirm the id exists.
    if (!skill) {
      throw new NotFoundException(`Provider skill with ID ${id} not found`);
    }

    return skill;
  }

  async findById(id: string): Promise<ProviderSkillEntity> {
    const skill = await this.providerSkillRepository.findOne({
      where: { id },
      relations: { user: true, serviceCategory: true },
    });

    if (!skill) {
      throw new NotFoundException(`Provider skill with ID ${id} not found`);
    }

    return skill;
  }

  async create(
    userId: string,
    createDto: CreateProviderSkillDto,
  ): Promise<ProviderSkillEntity> {
    // Verify service category exists and is active
    const serviceCategory = await this.serviceCategoryRepository.findOne({
      where: { id: createDto.serviceCategoryId, isActive: true },
    });

    if (!serviceCategory) {
      throw new BadRequestException('Service category not found or not active');
    }

    // Check if skill already exists for this user and category
    const existingSkill = await this.providerSkillRepository.findOne({
      where: { userId, serviceCategoryId: createDto.serviceCategoryId },
    });

    if (existingSkill) {
      throw new BadRequestException(
        'Skill already exists for this service category',
      );
    }

    // Email verification opens the workspace. Only approved KYC confers verified status.
    const accountVerified = await this.isAccountVerified(userId);

    const skill = this.providerSkillRepository.create({
      ...createDto,
      userId,
      isVerified: accountVerified,
      verificationNotes: accountVerified ? AUTO_VERIFIED_NOTE : null,
    });

    return this.providerSkillRepository.save(skill);
  }

  /**
   * A provider whose own account has not passed identity verification must not
   * produce a verified skill, no matter who calls this.
   */
  private async isAccountVerified(userId: string): Promise<boolean> {
    const application = await this.applicationRepository.findOne({
      where: { userId },
      select: { id: true, status: true },
    });
    return application?.status === ProviderOnboardingStatus.Approved;
  }

  async update(
    id: string,
    userId: string,
    updateDto: UpdateProviderSkillDto,
    isAdmin = false,
  ): Promise<ProviderSkillEntity> {
    const skill = await this.findById(id);

    // Only skill owner can update their skills (unless admin)
    if (!isAdmin && skill.userId !== userId) {
      throw new ForbiddenException("Cannot update another provider's skill");
    }

    // If updating service category, verify it exists and is active
    if (updateDto.serviceCategoryId) {
      const serviceCategory = await this.serviceCategoryRepository.findOne({
        where: { id: updateDto.serviceCategoryId, isActive: true },
      });

      if (!serviceCategory) {
        throw new BadRequestException(
          'Service category not found or not active',
        );
      }

      // Check for duplicate if changing category
      if (updateDto.serviceCategoryId !== skill.serviceCategoryId) {
        const existingSkill = await this.providerSkillRepository.findOne({
          where: {
            userId: skill.userId,
            serviceCategoryId: updateDto.serviceCategoryId,
          },
        });

        if (existingSkill) {
          throw new BadRequestException(
            'Skill already exists for this service category',
          );
        }
      }
    }

    // Only admins can update verification status and notes
    if (!isAdmin) {
      delete updateDto.isVerified;
      delete updateDto.verificationNotes;
    }

    Object.assign(skill, updateDto);
    return this.providerSkillRepository.save(skill);
  }

  /**
   * @param principal the authenticated caller. Passed in so the SEC-002
   *   ownership obligation this route raises is discharged here, at the point
   *   where the owning column is in hand: delete returns nothing, so the
   *   controller has no row left to compare.
   */
  async delete(
    id: string,
    userId: string,
    isAdmin = false,
    principal?: AuthorizationPrincipal,
  ): Promise<void> {
    const skill = await this.findById(id);

    // Only skill owner can delete their skills (unless admin)
    if (!isAdmin && skill.userId !== userId) {
      throw new ForbiddenException("Cannot delete another provider's skill");
    }
    if (principal) {
      assertOwnedResource(principal, skill.userId, 'providerSkill.userId');
    }

    await this.providerSkillRepository.remove(skill);
  }

  async verifySkill(
    id: string,
    isVerified: boolean,
    notes?: string,
  ): Promise<ProviderSkillEntity> {
    const skill = await this.findById(id);
    skill.isVerified = isVerified;
    skill.verificationNotes = notes || null;
    return this.providerSkillRepository.save(skill);
  }

  async findVerifiedSkillsByCategory(
    serviceCategoryId: string,
  ): Promise<ProviderSkillEntity[]> {
    return this.providerSkillRepository.find({
      where: {
        serviceCategoryId,
        isVerified: true,
      },
      relations: { user: true, serviceCategory: true },
    });
  }

  async getProviderSkillsCount(
    userId: string,
  ): Promise<{ total: number; verified: number }> {
    const [total, verified] = await Promise.all([
      this.providerSkillRepository.count({ where: { userId } }),
      this.providerSkillRepository.count({
        where: { userId, isVerified: true },
      }),
    ]);

    return { total, verified };
  }
}
