import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
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
    const saved = await this.profileRepository.save(profile);
    return this.toOwnerResponse(saved);
  }

  async updateLocation(
    userId: string,
    dto: UpdateProviderLocationDto,
  ): Promise<ProviderProfileResponseDto> {
    const profile = await this.findByUserId(userId);
    profile.baseLatitude = dto.latitude;
    profile.baseLongitude = dto.longitude;
    const saved = await this.profileRepository.save(profile);
    return this.toOwnerResponse(saved);
  }

  async checkCoverage(
    userId: string,
    target: CoverageCheckDto,
  ): Promise<CoverageCheckResponseDto> {
    const profile = await this.findByUserId(userId);
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
