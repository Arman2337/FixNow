import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ServiceCategoryEntity } from './service-category.entity';
import {
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  ServiceCategoryQueryDto,
  ServiceCategoryResponseDto,
} from './service-categories.dto';
import { AccountStatus } from '../users/account-status';
import { ProviderAvailabilityStatus } from '../../../shared/provider-availability.types';
import { ReviewModerationStatus } from '../../../shared/ratings.types';

/**
 * Real, honestly-computed per-category signals. Every field reflects rows that
 * actually exist in the database — there are no placeholders. On a freshly
 * migrated database (no providers, skills, availability, or reviews) each of
 * these is 0/null, and the client is expected to hide the corresponding UI.
 */
interface CategoryStats {
  verifiedProCount: number;
  onlineProCount: number;
  rating: number | null;
  reviewCount: number;
}

@Injectable()
export class ServiceCategoriesService {
  constructor(
    @InjectRepository(ServiceCategoryEntity)
    private readonly serviceCategoryRepository: Repository<ServiceCategoryEntity>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
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

  // ---------------------------------------------------------------------------
  // API-facing reads. These return plain response objects (not entities) so
  // every field — including the `pricing` getter and the aggregate signals
  // below — is serialized as an own property. (There is no
  // ClassSerializerInterceptor, so entity getters would otherwise be dropped
  // by the default JSON serializer.) The entity-returning methods above are
  // kept intact for in-process consumers (e.g. AI pricing/recommendation).
  // ---------------------------------------------------------------------------

  async findAllWithStats(
    query: ServiceCategoryQueryDto,
  ): Promise<ServiceCategoryResponseDto[]> {
    const categories = await this.findAll(query);
    const stats = await this.loadStats(categories.map((c) => c.id));
    return categories.map((c) => this.toResponse(c, stats.get(c.id)));
  }

  async findByIdWithStats(id: string): Promise<ServiceCategoryResponseDto> {
    const category = await this.findById(id);
    const stats = await this.loadStats([category.id]);
    return this.toResponse(category, stats.get(category.id));
  }

  async findBySlugWithStats(slug: string): Promise<ServiceCategoryResponseDto> {
    const category = await this.findBySlug(slug);
    const stats = await this.loadStats([category.id]);
    return this.toResponse(category, stats.get(category.id));
  }

  private toResponse(
    category: ServiceCategoryEntity,
    stats?: CategoryStats,
  ): ServiceCategoryResponseDto {
    return {
      id: category.id,
      name: category.name,
      slug: category.slug,
      description: category.description,
      iconName: category.iconName,
      displayOrder: category.displayOrder,
      isActive: category.isActive,
      isEmergency: category.isEmergency,
      pricing: category.pricing,
      verifiedProCount: stats?.verifiedProCount ?? 0,
      onlineProCount: stats?.onlineProCount ?? 0,
      rating: stats?.rating ?? null,
      reviewCount: stats?.reviewCount ?? 0,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    };
  }

  /**
   * Computes the honest per-category signals for the given category ids in
   * three grouped queries. Predicates mirror {@link MatchingService} so the
   * counts mean the same thing across the app:
   *  - verified pros: a verified skill held by an active account;
   *  - online now: those providers whose real-time availability is `online`
   *    and not expired;
   *  - rating: average + count of PUBLISHED reviews, joined to the reviewed
   *    booking's category.
   * Categories with no data simply don't appear in the result map, so callers
   * fall back to 0/null.
   */
  private async loadStats(ids: string[]): Promise<Map<string, CategoryStats>> {
    const stats = new Map<string, CategoryStats>();
    if (ids.length === 0) {
      return stats;
    }

    const ensure = (id: string): CategoryStats => {
      let entry = stats.get(id);
      if (!entry) {
        entry = {
          verifiedProCount: 0,
          onlineProCount: 0,
          rating: null,
          reviewCount: 0,
        };
        stats.set(id, entry);
      }
      return entry;
    };

    const verifiedRows = await this.dataSource.query<
      { category_id: string; count: number }[]
    >(
      `SELECT ps.service_category_id AS category_id,
              COUNT(DISTINCT ps.user_id)::int AS count
       FROM provider_skills ps
       JOIN users u ON u.id = ps.user_id
       WHERE ps.is_verified = true
         AND u.status = $1
         AND ps.service_category_id = ANY($2::uuid[])
       GROUP BY ps.service_category_id`,
      [AccountStatus.Active, ids],
    );
    for (const row of verifiedRows) {
      ensure(row.category_id).verifiedProCount = Number(row.count);
    }

    const onlineRows = await this.dataSource.query<
      { category_id: string; count: number }[]
    >(
      `SELECT ps.service_category_id AS category_id,
              COUNT(DISTINCT ps.user_id)::int AS count
       FROM provider_availability pa
       JOIN provider_skills ps
         ON ps.user_id = pa.user_id AND ps.is_verified = true
       JOIN users u ON u.id = pa.user_id
       WHERE pa.status = $1
         AND pa.status_expires_at > CURRENT_TIMESTAMP
         AND u.status = $2
         AND ps.service_category_id = ANY($3::uuid[])
       GROUP BY ps.service_category_id`,
      [ProviderAvailabilityStatus.Online, AccountStatus.Active, ids],
    );
    for (const row of onlineRows) {
      ensure(row.category_id).onlineProCount = Number(row.count);
    }

    const ratingRows = await this.dataSource.query<
      { category_id: string; rating: number | null; review_count: number }[]
    >(
      `SELECT b.service_category_id AS category_id,
              ROUND(AVG(r.rating)::numeric, 1)::float8 AS rating,
              COUNT(*)::int AS review_count
       FROM booking_reviews r
       JOIN bookings b ON b.id = r.booking_id AND b.deleted_at IS NULL
       WHERE r.moderation_status = $1
         AND b.service_category_id = ANY($2::uuid[])
       GROUP BY b.service_category_id`,
      [ReviewModerationStatus.PUBLISHED, ids],
    );
    for (const row of ratingRows) {
      const entry = ensure(row.category_id);
      entry.rating = row.rating === null ? null : Number(row.rating);
      entry.reviewCount = Number(row.review_count);
    }

    return stats;
  }
}
