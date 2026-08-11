import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ServiceCategoryEntity } from './service-category.entity';
import {
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  ServiceCategoryQueryDto,
} from './service-categories.dto';

@Injectable()
export class ServiceCategoriesService {
  constructor(
    @InjectRepository(ServiceCategoryEntity)
    private readonly serviceCategoryRepository: Repository<ServiceCategoryEntity>,
  ) {}

  async findAll(
    query: ServiceCategoryQueryDto,
  ): Promise<ServiceCategoryEntity[]> {
    const queryBuilder =
      this.serviceCategoryRepository.createQueryBuilder('category');

    if (query.isActive !== undefined) {
      queryBuilder.andWhere('category.isActive = :isActive', {
        isActive: query.isActive,
      });
    }

    if (query.isEmergency !== undefined) {
      queryBuilder.andWhere('category.isEmergency = :isEmergency', {
        isEmergency: query.isEmergency,
      });
    }

    queryBuilder
      .orderBy('category.displayOrder', 'ASC')
      .addOrderBy('category.name', 'ASC');

    return queryBuilder.getMany();
  }

  async findById(id: string): Promise<ServiceCategoryEntity> {
    const category = await this.serviceCategoryRepository.findOne({
      where: { id },
      relations: ['providerSkills'],
    });

    if (!category) {
      throw new NotFoundException(`Service category with ID ${id} not found`);
    }

    return category;
  }

  async findBySlug(slug: string): Promise<ServiceCategoryEntity> {
    const category = await this.serviceCategoryRepository.findOne({
      where: { slug },
      relations: ['providerSkills'],
    });

    if (!category) {
      throw new NotFoundException(
        `Service category with slug ${slug} not found`,
      );
    }

    return category;
  }

  async create(
    createDto: CreateServiceCategoryDto,
  ): Promise<ServiceCategoryEntity> {
    const category = this.serviceCategoryRepository.create(createDto);
    return this.serviceCategoryRepository.save(category);
  }

  async update(
    id: string,
    updateDto: UpdateServiceCategoryDto,
  ): Promise<ServiceCategoryEntity> {
    const category = await this.findById(id);
    Object.assign(category, updateDto);
    return this.serviceCategoryRepository.save(category);
  }

  async delete(id: string): Promise<void> {
    const result = await this.serviceCategoryRepository.delete(id);
    if (result.affected === 0) {
      throw new NotFoundException(`Service category with ID ${id} not found`);
    }
  }

  async getActiveCategories(): Promise<ServiceCategoryEntity[]> {
    return this.findAll({ isActive: true });
  }

  async getEmergencyCategories(): Promise<ServiceCategoryEntity[]> {
    return this.findAll({ isActive: true, isEmergency: true });
  }
}
