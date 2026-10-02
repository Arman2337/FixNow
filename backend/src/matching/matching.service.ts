import { Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, SelectQueryBuilder } from 'typeorm';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { AccountStatus } from '../users/account-status';
import { ProviderAvailabilityStatus } from '../../../shared/provider-availability.types';
import { ObservabilityService } from '../observability/observability.service';

export interface MatchedProvider {
  providerId: string;
  distanceKm: number;
}

/**
 * Great-circle distance in kilometres.
 *
 * Written once as a constant because four public methods below express the same
 * predicate, and BUG-007 was caused by two of them disagreeing about it: the
 * shortlist applied a `LIMIT` that the eligibility check did not, so a provider's
 * answer depended on their rank. A predicate that is typed in one place cannot
 * drift from the others.
 *
 * `LEAST`/`GREATEST` clamp the `acos` argument: floating-point error can push it
 * marginally outside [-1, 1], and Postgres raises on that rather than returning
 * NaN.
 */
const HAVERSINE_SQL = `
  (6371 * acos(LEAST(1, GREATEST(-1,
    cos(radians(:lat)) *
    cos(radians(profile.baseLatitude)) *
    cos(radians(profile.baseLongitude) - radians(:lng)) +
    sin(radians(:lat)) *
    sin(radians(profile.baseLatitude))
  ))))
`;

/**
 * BUG-016. How old a provider's self-declared base location may be and still
 * count as dispatchable.
 *
 * A base location is a home base, not a live position: a provider legitimately
 * sets it once a week, so requiring live GPS would be wrong. But the table had
 * no record of *when* it was set, so a profile pinned eight months ago ranked
 * identically to one set a second ago - inside or outside every radius, with
 * nothing to tell the two cases apart. `base_location_updated_at` (added in
 * `DispatchIntegrityAndProviderFreshness1789750100000`) makes the staleness
 * expressible, and this bound is what consumes it.
 *
 * After a week a provider's own app nudges them to refresh; until then they are
 * simply not offered work, which is the honest outcome - the alternative is
 * dispatching a technician who is not where the map says they are.
 */
const DEFAULT_MAX_LOCATION_AGE_DAYS = 7;

@Injectable()
export class MatchingService {
  constructor(
    @InjectRepository(ProviderProfileEntity)
    private readonly profileRepository: Repository<ProviderProfileEntity>,
    private readonly config?: ConfigService,
    // `ObservabilityModule` is `@Global()`, so the running application always
    // injects this; it is optional so a unit test can build the service without
    // a metrics graph.
    @Optional()
    private readonly observability?: ObservabilityService,
  ) {}

  /**
   * The one eligibility predicate.
   *
   * Every public method below is this query with a different projection: a
   * shortlist adds `ORDER BY`/`LIMIT`, a single-provider check adds a
   * `user_id` filter, a supply count adds neither. Keeping them here is what
   * makes "who do we notify", "may this provider take it" and "is there anyone"
   * three answers to three different questions rather than three subtly
   * different definitions of the same one.
   */
  private eligibleQuery(): SelectQueryBuilder<ProviderProfileEntity> {
    return this.profileRepository
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
      .andWhere('skill.is_verified = :isVerified', { isVerified: true })
      .andWhere('category.is_active = :categoryActive', {
        categoryActive: true,
      })
      .andWhere('profile.baseLocationUpdatedAt >= :freshnessFloor', {
        freshnessFloor: this.locationFreshnessFloor(),
      });
  }

  /** BUG-016: the oldest a dispatch base location may be and still be offered work. */
  get maxLocationAgeDays(): number {
    const configured = Number(
      this.config?.get<string>('PROVIDER_MAX_LOCATION_AGE_DAYS'),
    );
    return Number.isFinite(configured) && configured > 0
      ? Math.trunc(configured)
      : DEFAULT_MAX_LOCATION_AGE_DAYS;
  }

  private locationFreshnessFloor(now = new Date()): Date {
    return new Date(now.getTime() - this.maxLocationAgeDays * 86_400_000);
  }

  /**
   * Finds eligible providers for a requested service and location.
   *
   * Criteria:
   * 1. User account is active.
   * 2. Provider availability is online.
   * 3. Provider has the requested skill and is verified.
   * 4. The requested location is within the provider's service radius.
   * 5. The provider's base location is recent enough to be trustworthy.
   *
   * Returns a list of provider IDs and their distance to the requested location,
   * nearest first. Does NOT return exact provider coordinates, to preserve
   * privacy.
   *
   * The `LIMIT` here is a fan-out shortlist bound and nothing else. It is
   * deliberately absent from `isProviderEligible` - see BUG-007 there.
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
    const boundedMultiplier = this.boundedRadius(radiusMultiplier);

    const raw = await this.eligibleQuery()
      .andWhere('skill.service_category_id = :categoryId', {
        categoryId: serviceCategoryId,
      })
      .andWhere(
        `${HAVERSINE_SQL} <= profile.serviceRadiusKm * ${boundedMultiplier}`,
        {
          lat: locationLat,
          lng: locationLng,
        },
      )
      .select('profile.userId', 'providerId')
      .addSelect(HAVERSINE_SQL, 'distanceKm')
      .orderBy('distanceKm', 'ASC')
      // Deterministic tie-break, so a wave is reproducible. Note this is also
      // what made BUG-007's starvation perfectly repeatable: the same nearest
      // providers won every job. Fairness belongs in the scoring layer, not in
      // a tie-break on a distance query.
      .addOrderBy('profile.userId', 'ASC')
      .limit(boundedLimit)
      .getRawMany<{ providerId: string; distanceKm: string }>();

    return raw.map((row) => ({
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
   * eligible for this booking" - a factually false answer, and one that would
   * lock out roughly 90% of a 500-plumber metro.
   *
   * Same predicate, no `ORDER BY` and no `LIMIT`, so the answer cannot depend on
   * the provider's rank. Kept as its own method rather than a flag on the
   * shortlist, because ranking a shortlist and judging eligibility are
   * different questions and the shared builder is where they meet.
   */
  async isProviderEligible(
    providerId: string,
    locationLat: number,
    locationLng: number,
    serviceCategoryId: string,
    radiusMultiplier = 1,
  ): Promise<boolean> {
    // Observability. This predicate is a haversine evaluation across every
    // skill-matching provider, so it is the single most expensive query on the
    // accept path — and BUG-004 was precisely this query being called 200 times
    // per request. Without a duration there is no way to see that regression
    // coming back, because a slow query and a fast one both return `true`.
    const startedAt = process.hrtime.bigint();
    try {
      return (
        (await this.countWhereEligible(
          locationLat,
          locationLng,
          serviceCategoryId,
          this.boundedRadius(radiusMultiplier),
          'profile.user_id = :providerId',
          { providerId },
        )) > 0
      );
    } finally {
      this.observability?.observeMatching(
        Number(process.hrtime.bigint() - startedAt) / 1e9,
        'eligibility',
      );
    }
  }

  /**
   * How many providers could take work at this location and category right now.
   *
   * BUG-014. The zero-provider case is the most common failure mode in a
   * marketplace launch - nobody is online yet - and it was completely
   * unexpressible. Nothing in the codebase could answer "is there any supply
   * here", so `create()` returned 201, the booking sat in `REQUESTED` with no
   * scheduled exit, and the customer watched a spinner forever.
   *
   * The same predicate with neither ordering nor limit, counted rather than
   * fetched because the answer is only ever compared against zero.
   */
  async countEligibleProviders(
    locationLat: number,
    locationLng: number,
    serviceCategoryId: string,
    radiusMultiplier = 1,
  ): Promise<number> {
    return this.countWhereEligible(
      locationLat,
      locationLng,
      serviceCategoryId,
      this.boundedRadius(radiusMultiplier),
    );
  }

  /**
   * The distance from a provider to a job, or null when they are not eligible.
   *
   * BUG-004. `getAvailableRequests` used to call `findEligibleProviders` once per
   * candidate booking and then search that shortlist for the asking provider.
   * That was wrong twice: up to 200 sequential haversine queries per request, and
   * the same rank limit as BUG-007, so a provider eligible for a job but ranked
   * 51st-or-better-nearest was silently dropped from their own list of work.
   *
   * Scoped to one provider with no LIMIT, so the answer cannot depend on rank,
   * and it returns the distance the caller needs to display.
   */
  async findProviderDistance(
    providerId: string,
    locationLat: number,
    locationLng: number,
    serviceCategoryId: string,
    radiusMultiplier = 1,
  ): Promise<number | null> {
    const rows = await this.eligibleQuery()
      .andWhere('skill.service_category_id = :categoryId', {
        categoryId: serviceCategoryId,
      })
      .andWhere('profile.user_id = :providerId', { providerId })
      .andWhere(
        `${HAVERSINE_SQL} <= profile.serviceRadiusKm * ${this.boundedRadius(radiusMultiplier)}`,
        { lat: locationLat, lng: locationLng },
      )
      .select(HAVERSINE_SQL, 'distanceKm')
      .limit(1)
      .getRawMany<{ distanceKm: string }>();

    if (rows.length === 0) return null;
    return parseFloat(rows[0].distanceKm);
  }

  /**
   * Can this account take this category's work at all?
   *
   * The narrower sibling of `isProviderEligible`, for privileged flows that name
   * the provider themselves rather than letting matching choose (BUG-011/SEC-007,
   * the guarantee re-service). It answers "is this a real, active provider
   * qualified for this work", and deliberately does NOT ask whether they are
   * currently Online or within radius: an administrator scheduling a remedy for
   * a customer the platform failed is entitled to pick a provider who has gone
   * offline, and refusing would leave the guarantee un-actionable.
   *
   * Before this existed the endpoint took `providerId` straight from the request
   * body and wrote it onto a live booking, so any account id - including a
   * customer's - could be attached to real work.
   */
  async isProviderQualifiedForCategory(
    providerId: string,
    serviceCategoryId: string,
  ): Promise<boolean> {
    const count = await this.profileRepository
      .createQueryBuilder('profile')
      .innerJoin('profile.user', 'user')
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
      .andWhere('skill.service_category_id = :categoryId', {
        categoryId: serviceCategoryId,
      })
      .andWhere('skill.is_verified = :isVerified', { isVerified: true })
      .andWhere('category.is_active = :categoryActive', {
        categoryActive: true,
      })
      .getCount();

    return count > 0;
  }

  private countWhereEligible(
    locationLat: number,
    locationLng: number,
    serviceCategoryId: string,
    radiusMultiplier: number,
    extraWhere?: string,
    extraParams?: Record<string, unknown>,
  ): Promise<number> {
    const query = this.eligibleQuery()
      .andWhere('skill.service_category_id = :categoryId', {
        categoryId: serviceCategoryId,
      })
      .andWhere(
        `${HAVERSINE_SQL} <= profile.serviceRadiusKm * ${radiusMultiplier}`,
        { lat: locationLat, lng: locationLng },
      );
    if (extraWhere) query.andWhere(extraWhere, extraParams ?? {});
    return query.getCount();
  }

  private boundedRadius(multiplier: number): number {
    return Math.min(Math.max(Math.trunc(multiplier) || 1, 1), 4);
  }
}
