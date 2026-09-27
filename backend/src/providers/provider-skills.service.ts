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
import { UserEntity } from '../users/user.entity';
import { AccountStatus } from '../users/account-status';
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
    @InjectRepository(UserEntity)
    private readonly userRepository: Repository<UserEntity>,
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
      .addOrderBy('category.name', 'ASC');

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

    // A skill is not self-certified. It inherits the provider's own account
    // verification: the authorization guard already refuses any account that is
    // not Active, and matching requires Active too, so reaching this point means
    // the identity behind the skill has been checked.
    //
    // This used to hardcode `isVerified: true` with no reference to the
    // account, which meant the flag carried no information and the admin
    // verification route could never be the thing that granted it. `update()`
    // already refuses to let a provider set this field, so the create path was
    // the one place a provider could assert it. Deciding it from the account
    // keeps onboarding fast while making the flag mean something.
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
    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: { id: true, status: true },
    });
    return user?.status === AccountStatus.Active;
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

  async delete(id: string, userId: string, isAdmin = false): Promise<void> {
    const skill = await this.findById(id);

    // Only skill owner can delete their skills (unless admin)
    if (!isAdmin && skill.userId !== userId) {
      throw new ForbiddenException("Cannot delete another provider's skill");
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
