import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import { assertOwnedResource } from '../common/authorization/resource-ownership';
import { ProviderApplicationEntity } from './provider-application.entity';
import { ProviderProfileEntity } from './provider-profile.entity';
import { ProviderSkillEntity } from './provider-skill.entity';
import {
  CoverageCheckDto,
  CoverageCheckResponseDto,
  ProviderProfileResponseDto,
  UpdateProviderLocationDto,
  UpsertProviderProfileDto,
} from './provider-profile.dto';

const EARTH_RADIUS_KM = 6371.0088;

type ProviderStatsRow = {
  rating: number;
  reviewCount: number;
  completedJobs: number;
  earningsMinor: number;
};

@Injectable()
export class ProviderProfileService {
  constructor(
    @InjectRepository(ProviderProfileEntity)
    private readonly profileRepository: Repository<ProviderProfileEntity>,
    @InjectRepository(ProviderApplicationEntity)
    private readonly applicationRepository: Repository<ProviderApplicationEntity>,
    @InjectRepository(ProviderSkillEntity)
    private readonly skillRepository: Repository<ProviderSkillEntity>,
    private readonly dataSource: DataSource,
  ) {}

  async getOwnProfile(userId: string): Promise<ProviderProfileResponseDto> {
    const profile = await this.findByUserId(userId);
    return this.toOwnerResponse(profile);
  }

  async upsertOwnProfile(
    userId: string,
    dto: UpsertProviderProfileDto,
  ): Promise<ProviderProfileResponseDto> {
    const application = await this.applicationRepository.findOne({
      where: { userId },
    });
    if (!application) {
      throw new NotFoundException('Provider application not found');
    }

    const existing = await this.profileRepository.findOne({
      where: { userId },
    });
    const profile = existing
      ? Object.assign(existing, dto)
      : this.profileRepository.create({ userId, ...dto });

    // BUG-016: registration also sets coordinates, from the same request body,
    // so the freshness stamp has to be written here too. A profile created
    // through this path and then never touched would otherwise carry the column
    // default, which is correct only by accident - and a stale base location
    // silently drops a provider out of matching after seven days.
    if (
      profile.baseLatitude !== existing?.baseLatitude ||
      profile.baseLongitude !== existing?.baseLongitude
    ) {
      profile.baseLocationUpdatedAt = new Date();
    }

    const saved = await this.profileRepository.save(profile);
    return this.toOwnerResponse(saved);
  }

  /**
   * BUG-016. A provider's dispatch base location.
   *
   * These coordinates are the only input to dispatch distance, so this is not a
   * cosmetic profile field - it decides which jobs a provider is offered. Three
   * controls make it trustworthy:
   *
   *   1. `base_location_updated_at` is stamped here, which is what
   *      `MatchingService`'s staleness bound reads. Before this the table had no
   *      record of *when* a location was set, so a profile pinned eight months
   *      ago ranked identically to one set a second ago.
   *   2. The endpoint is rate-limited in the controller, because at the global
   *      60/min a provider could re-centre on a dense area as fast as the API
   *      would answer.
   *   3. The range CHECK constraints (restored by BUG-001) bound the value at
   *      the database, so a coordinate outside +/-90/180 cannot persist even if
   *      validation is bypassed.
   *
   * A base location is a home base, not a live position: a provider legitimately
   * sets it about once a week. The fix is a staleness bound, not continuous
   * tracking - live per-booking GPS is a separate, already-implemented path in
   * `LocationService`.
   */
  async updateLocation(
    userId: string,
    dto: UpdateProviderLocationDto,
  ): Promise<ProviderProfileResponseDto> {
    const profile = await this.findByUserId(userId);
    profile.baseLatitude = dto.latitude;
    profile.baseLongitude = dto.longitude;
    profile.baseLocationUpdatedAt = new Date();
    const saved = await this.profileRepository.save(profile);
    return this.toOwnerResponse(saved);
  }

  async checkCoverage(
    principal: AuthorizationPrincipal,
    target: CoverageCheckDto,
  ): Promise<CoverageCheckResponseDto> {
    const profile = await this.findByUserId(principal.userId);
    // SEC-002: the result is a bare boolean, so the only place the profile's
    // real owning column is in hand is here.
    assertOwnedResource(principal, profile.userId, 'providerProfile.userId');
    return {
      isWithinServiceArea:
        ProviderProfileService.distanceKm(
          profile.baseLatitude,
          profile.baseLongitude,
          target.latitude,
          target.longitude,
        ) <= profile.serviceRadiusKm,
    };
  }

  static distanceKm(
    latitudeA: number,
    longitudeA: number,
    latitudeB: number,
    longitudeB: number,
  ): number {
    const radians = (degrees: number) => (degrees * Math.PI) / 180;
    const latitudeDelta = radians(latitudeB - latitudeA);
    const longitudeDelta = radians(longitudeB - longitudeA);
    const a =
      Math.sin(latitudeDelta / 2) ** 2 +
      Math.cos(radians(latitudeA)) *
        Math.cos(radians(latitudeB)) *
        Math.sin(longitudeDelta / 2) ** 2;
    return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  private async findByUserId(userId: string): Promise<ProviderProfileEntity> {
    const profile = await this.profileRepository.findOne({ where: { userId } });
    if (!profile) {
      throw new NotFoundException('Provider profile not found');
    }
    return profile;
  }

  private async toOwnerResponse(
    profile: ProviderProfileEntity,
  ): Promise<ProviderProfileResponseDto> {
    const skills = await this.skillRepository.find({
      where: { userId: profile.userId },
      select: { id: true },
      order: { createdAt: 'ASC' },
    });

    // Scalar subqueries, not a three-way join: joining bookings x reviews x
    // payment_orders in one SELECT fanned the rows out, so a booking with two
    // paid orders counted its review twice in AVG and doubled its earnings in
    // SUM. Each figure is now independent of the others' cardinality.
    const stats = await this.dataSource.query<ProviderStatsRow[]>(
      `
      SELECT
        (
          SELECT COALESCE(AVG(r.rating), 0)::float
          FROM booking_reviews r
          JOIN bookings b2 ON b2.id = r.booking_id
          WHERE b2.provider_id = $1
            AND b2.status = 'COMPLETED'
            AND r.moderation_status = 'PUBLISHED'
        ) AS "rating",
        (
          SELECT COUNT(*)::int
          FROM booking_reviews r
          JOIN bookings b3 ON b3.id = r.booking_id
          WHERE b3.provider_id = $1
            AND b3.status = 'COMPLETED'
            AND r.moderation_status = 'PUBLISHED'
        ) AS "reviewCount",
        (
          SELECT COUNT(*)::int FROM bookings b
          WHERE b.provider_id = $1 AND b.status = 'COMPLETED'
        ) AS "completedJobs",
        (
          SELECT COALESCE(SUM(po.amount_minor), 0)::int
          FROM payment_orders po
          JOIN bookings b4 ON b4.id = po.booking_id
          WHERE b4.provider_id = $1 AND po.status = 'PAID'
        ) AS "earningsMinor"
      `,
      [profile.userId],
    );

    const statsRow = stats[0];
    const reviewCount = statsRow?.reviewCount ?? 0;

    return {
      ...profile,
      skillIds: skills.map((skill) => skill.id),
      stats: {
        // 0 with no published reviews is not a 0-star rating, it is an absence
        // of one. reviewCount lets the client say "Not yet rated" honestly
        // instead of rendering a number it invented.
        rating: statsRow?.rating ?? 0,
        reviewCount,
        completedJobs: statsRow?.completedJobs ?? 0,
        earningsMinor: statsRow?.earningsMinor ?? 0,
        // Only meaningful once a provider has been offered work; 0 otherwise.
        acceptanceRate: 0,
      },
    };
  }
}
