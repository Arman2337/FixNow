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
    /** FN-063 wave-2 widening: multiplies each provider's own radius. */
    radiusMultiplier = 1,
  ): Promise<MatchedProvider[]> {
    const boundedLimit = Math.min(Math.max(Math.trunc(limit), 1), 50);
    const boundedMultiplier = Math.min(Math.max(radiusMultiplier, 1), 4);
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
      .andWhere(
        `${haversineSql} <= profile.serviceRadiusKm * ${boundedMultiplier}`,
        {
          lat: locationLat,
          lng: locationLng,
        },
      )
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

  /**
   * Whether one specific provider may take a specific job.
   *
   * BUG-007. `acceptBooking` used to decide eligibility by looking for the
   * provider inside `findEligibleProviders(..., 50)`. That list is a
   * distance-ordered fan-out capped at 50, so in a city with more than 50
   * eligible providers everyone past the cut was refused with "Provider is not
   * eligible for this booking" - a factually false answer. The tie-break is
   * `profile.userId ASC`, so the outcome was also perfectly deterministic: the
   * same 50 providers won every job, forever.
   *
   * This is the same predicate with no `ORDER BY` and no `LIMIT`, so the answer
   * cannot depend on a provider's rank. Kept separate from
   * `findEligibleProviders` rather than reusing it, because ranking a shortlist
   * and judging eligibility are different questions.
   */
  async isProviderEligible(
    providerId: string,
    locationLat: number,
    locationLng: number,
    serviceCategoryId: string,
    radiusMultiplier = 1,
  ): Promise<boolean> {
    const boundedMultiplier = Math.min(Math.max(radiusMultiplier, 1), 4);
    const haversineSql = `
      (6371 * acos(LEAST(1, GREATEST(-1,
        cos(radians(:lat)) *
        cos(radians(profile.baseLatitude)) *
        cos(radians(profile.baseLongitude) - radians(:lng)) +
        sin(radians(:lat)) *
        sin(radians(profile.baseLatitude))
      ))))
    `;

    const count = await this.profileRepository
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
      .where('profile.user_id = :providerId', { providerId })
      .andWhere('user.status = :accountStatus', {
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
      .andWhere(
        `${haversineSql} <= profile.serviceRadiusKm * ${boundedMultiplier}`,
        { lat: locationLat, lng: locationLng },
      )
      .getCount();

    return count > 0;
  }
}
