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
import {
  CreateProviderSkillDto,
  UpdateProviderSkillDto,
  ProviderSkillQueryDto,
} from './provider-skills.dto';

@Injectable()
export class ProviderSkillsService {
  constructor(
    @InjectRepository(ProviderSkillEntity)
    private readonly providerSkillRepository: Repository<ProviderSkillEntity>,
    @InjectRepository(ServiceCategoryEntity)
    private readonly serviceCategoryRepository: Repository<ServiceCategoryEntity>,
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

    const skill = this.providerSkillRepository.create({
      ...createDto,
      userId,
      isVerified: false, // Skills start unverified
    });

    return this.providerSkillRepository.save(skill);
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
