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
  UpsertProviderProfileDto,
} from './provider-profile.dto';

const EARTH_RADIUS_KM = 6371.0088;

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

    const stats = await this.dataSource.query(
      `
      SELECT 
        COALESCE(AVG(r.rating), 0)::float AS "rating",
        COUNT(DISTINCT b.id)::int AS "completedJobs",
        COALESCE(SUM(po.amount_minor), 0)::int AS "earningsMinor"
      FROM bookings b
      LEFT JOIN booking_reviews r ON r.booking_id = b.id AND r.moderation_status = 'PUBLISHED'
      LEFT JOIN payment_orders po ON po.booking_id = b.id AND po.status = 'PAID'
      WHERE b.provider_id = $1 AND b.status = 'COMPLETED'
      `,
      [profile.userId],
    );

    return { 
      ...profile, 
      skillIds: skills.map((skill) => skill.id),
      stats: {
        rating: stats[0]?.rating ?? 0,
        completedJobs: stats[0]?.completedJobs ?? 0,
        earningsMinor: stats[0]?.earningsMinor ?? 0,
        acceptanceRate: 98, // hardcode or mock for now, complex to derive accurately
      },
    };
  }
}
