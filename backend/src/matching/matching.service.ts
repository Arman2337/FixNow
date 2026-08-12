import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { AccountStatus } from '../users/account-status';
import { ProviderAvailabilityStatus } from '../../../shared/provider-availability.types';

export interface MatchedProvider {
  providerId: string;
  distanceKm: number;
}

@Injectable()
export class MatchingService {
  constructor(
    @InjectRepository(ProviderProfileEntity)
    private readonly profileRepository: Repository<ProviderProfileEntity>,
  ) {}

  /**
   * Finds eligible providers for a requested service and location.
   * Criteria:
   * 1. User account is active.
   * 2. Provider availability is online.
   * 3. Provider has the requested skill and is verified.
   * 4. The requested location is within the provider's service radius.
   *
   * Returns a list of provider IDs and their distance to the requested location.
   * Orders by distance ascending.
   * Does NOT return exact provider coordinates to preserve privacy.
   */
  async findEligibleProviders(
    locationLat: number,
    locationLng: number,
    serviceCategoryId: string,
    limit = 50,
  ): Promise<MatchedProvider[]> {
    const boundedLimit = Math.min(Math.max(Math.trunc(limit), 1), 50);
    const haversineSql = `
      (6371 * acos(LEAST(1, GREATEST(-1,
        cos(radians(:lat)) *
        cos(radians(profile.baseLatitude)) *
        cos(radians(profile.baseLongitude) - radians(:lng)) +
        sin(radians(:lat)) *
        sin(radians(profile.baseLatitude))
      ))))
    `;

    const query = this.profileRepository
      .createQueryBuilder('profile')
      .innerJoin('profile.user', 'user')
      .innerJoin(
        'provider_availability',
        'availability',
        'availability.user_id = profile.user_id',
      )
      .innerJoin('provider_skills', 'skill', 'skill.user_id = profile.user_id')
      .innerJoin(
        'service_categories',
        'category',
        'category.id = skill.service_category_id',
      )
      .where('user.status = :accountStatus', {
        accountStatus: AccountStatus.Active,
      })
      .andWhere('availability.status = :availStatus', {
        availStatus: ProviderAvailabilityStatus.Online,
      })
      .andWhere('availability.status_expires_at > CURRENT_TIMESTAMP')
      .andWhere('skill.service_category_id = :categoryId', {
        categoryId: serviceCategoryId,
      })
      .andWhere('skill.is_verified = :isVerified', { isVerified: true })
      .andWhere('category.is_active = :categoryActive', {
        categoryActive: true,
      })
      .andWhere(`${haversineSql} <= profile.serviceRadiusKm`, {
        lat: locationLat,
        lng: locationLng,
      })
      .select('profile.userId', 'providerId')
      .addSelect(haversineSql, 'distanceKm')
      .orderBy('distanceKm', 'ASC')
      .addOrderBy('profile.userId', 'ASC')
      .limit(boundedLimit);

    const rawResults = await query.getRawMany<{
      providerId: string;
      distanceKm: string;
    }>();

    return rawResults.map((row) => ({
      providerId: row.providerId,
      distanceKm: parseFloat(row.distanceKm),
    }));
  }
}
