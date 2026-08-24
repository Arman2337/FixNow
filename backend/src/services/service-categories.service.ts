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
      relations: { providerSkills: true },
    });

    if (!category) {
      throw new NotFoundException(`Service category with ID ${id} not found`);
    }

    return category;
  }

  async findBySlug(slug: string): Promise<ServiceCategoryEntity> {
    const category = await this.serviceCategoryRepository.findOne({
      where: { slug },
      relations: { providerSkills: true },
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
    const { pricing, ...rest } = createDto;
    const category = this.serviceCategoryRepository.create({
      ...rest,
      priceAmount: pricing?.amountMinor ?? null,
      priceCurrency: pricing?.currency ?? null,
    });
    return this.serviceCategoryRepository.save(category);
  }

  async update(
    id: string,
    updateDto: UpdateServiceCategoryDto,
  ): Promise<ServiceCategoryEntity> {
    const category = await this.findById(id);
    const { pricing, ...rest } = updateDto;
    Object.assign(category, rest);
    if (pricing !== undefined) {
      // Absent leaves pricing unchanged; null clears back to "price on
      // request"; an object sets or replaces the published price.
      category.priceAmount = pricing ? pricing.amountMinor : null;
      category.priceCurrency = pricing ? pricing.currency : null;
    }
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
