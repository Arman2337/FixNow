import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { Repository } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { ProviderOnboardingStatus } from '../providers/provider-onboarding-status';
import { TRUST_RULES } from '../trust/trust.service';

const ANALYTICS_CACHE_KEY = 'admin:analytics:operational';
/**
 * Two minutes, at the short end of the 1-5 minute range the audit suggested.
 *
 * This is an operational dashboard, so staleness costs a refresh cycle rather
 * than correctness. The shorter TTL is chosen because a booking that completes
 * while an operator is watching a live incident should appear promptly.
 */
const ANALYTICS_CACHE_TTL_MS = 120_000;

export interface AnalyticsResponse {
  generatedAt: string;
  bookings: {
    total: number;
    completed: number;
    cancelled: number;
    pending: number;
  };
  providers: {
    total: number;
    active: number;
    verified: number;
    pendingVerification: number;
  };
  services: {
    topCategories: { id: string; name: string; count: number }[];
  };
  emergencies: {
    activeRequests: number;
    totalRequests: number;
  };
  /** FN-111: platform-wide rolling accept-time signal, hidden when thin. */
  trust: {
    averageAcceptMinutes: number | null;
    sampleSize: number;
    windowDays: number;
  };
}

@Injectable()
export class AdminAnalyticsService {
  private readonly logger = new Logger(AdminAnalyticsService.name);

  constructor(
    @InjectRepository(Booking)
    private readonly bookings: Repository<Booking>,
    @InjectRepository(ProviderApplicationEntity)
    private readonly applications: Repository<ProviderApplicationEntity>,
    @InjectRepository(ServiceCategoryEntity)
    private readonly services: Repository<ServiceCategoryEntity>,
    @Inject(CACHE_MANAGER) private readonly cache: Cache,
  ) {}

  /**
   * Operational dashboard figures.
   *
   * The audit counted nine sequential aggregate queries per call. This wraps
   * them in a short-TTL cache rather than collapsing them into one statement,
   * because a dashboard is read far more often than the underlying numbers
   * change, and a cache is the fix the audit itself proposed.
   *
   * A cache read or write failure is logged and ignored: analytics is
   * observational, and a Redis hiccup must not turn a dashboard into a 500.
   */
  async getOperationalAnalytics(): Promise<AnalyticsResponse> {
    try {
      const cached =
        await this.cache.get<AnalyticsResponse>(ANALYTICS_CACHE_KEY);
      if (cached) return cached;
    } catch (error) {
      this.logger.warn(
        `Analytics cache read failed, computing fresh: ${String(error)}`,
      );
    }

    const response = await this.computeOperationalAnalytics();

    try {
      await this.cache.set(
        ANALYTICS_CACHE_KEY,
        response,
        ANALYTICS_CACHE_TTL_MS,
      );
    } catch (error) {
      this.logger.warn(`Analytics cache write failed: ${String(error)}`);
    }
    return response;
  }

  private async computeOperationalAnalytics(): Promise<AnalyticsResponse> {
    const totalBookings = await this.bookings.count();
    const completedBookings = await this.bookings.count({
      where: { status: BookingStatus.COMPLETED },
    });
    const cancelledBookings = await this.bookings.count({
      where: { status: BookingStatus.CANCELLED },
    });
    const pendingBookings = await this.bookings.count({
      where: [
        { status: BookingStatus.REQUESTED },
        { status: BookingStatus.ASSIGNED },
        { status: BookingStatus.EN_ROUTE },
        { status: BookingStatus.IN_PROGRESS },
      ],
    });

    const totalProviders = await this.applications.count();
    const activeProviders = await this.applications.count({
      where: { status: ProviderOnboardingStatus.Approved },
    });
    const verifiedProviders = activeProviders; // Approved implies verified
    const pendingProviders = await this.applications.count({
      where: { status: ProviderOnboardingStatus.UnderReview },
    });

    const topCategoryRows = await this.bookings
      .createQueryBuilder('booking')
      .select('booking.service_category_id', 'categoryId')
      .addSelect('COUNT(booking.id)', 'count')
      .groupBy('booking.service_category_id')
      .orderBy('count', 'DESC')
      .limit(5)
      .getRawMany<{ categoryId: string; count: string }>();

    const topCategories = await Promise.all(
      topCategoryRows.map(async (row) => {
        const category = await this.services.findOne({
          where: { id: row.categoryId },
        });
        return {
          id: row.categoryId,
          name: category?.name ?? 'Unknown',
          count: parseInt(row.count, 10),
        };
      }),
    );

    const emergencyCategories = await this.services.find({
      where: { isEmergency: true },
    });
    const emergencyCategoryIds = emergencyCategories.map((c) => c.id);

    let activeEmergencyRequests = 0;
    let totalEmergencyRequests = 0;

    if (emergencyCategoryIds.length > 0) {
      const qbActive = this.bookings
        .createQueryBuilder('booking')
        .where('booking.service_category_id IN (:...ids)', {
          ids: emergencyCategoryIds,
        })
        .andWhere('booking.status IN (:...statuses)', {
          statuses: [
            BookingStatus.REQUESTED,
            BookingStatus.ASSIGNED,
            BookingStatus.EN_ROUTE,
            BookingStatus.IN_PROGRESS,
          ],
        });
      activeEmergencyRequests = await qbActive.getCount();

      const qbTotal = this.bookings
        .createQueryBuilder('booking')
        .where('booking.service_category_id IN (:...ids)', {
          ids: emergencyCategoryIds,
        });
      totalEmergencyRequests = await qbTotal.getCount();
    }

    const acceptWindowStart = new Date();
    acceptWindowStart.setUTCDate(
      acceptWindowStart.getUTCDate() - TRUST_RULES.acceptTimeWindowDays,
    );
    const acceptRow = await this.bookings
      .createQueryBuilder('booking')
      .select('COUNT(booking.id)', 'sample')
      .addSelect(
        'AVG(EXTRACT(EPOCH FROM (booking.assigned_at - booking.created_at)) / 60)',
        'avgMinutes',
      )
      .where('booking.assigned_at IS NOT NULL')
      .andWhere('booking.created_at > :acceptWindowStart', {
        acceptWindowStart,
      })
      .getRawOne<{ sample: string; avgMinutes: string | null }>();
    const acceptSample = parseInt(acceptRow?.sample ?? '0', 10);
    const parsedAcceptMinutes =
      acceptRow?.avgMinutes == null ? null : parseFloat(acceptRow.avgMinutes);

    return {
      generatedAt: new Date().toISOString(),
      bookings: {
        total: totalBookings,
        completed: completedBookings,
        cancelled: cancelledBookings,
        pending: pendingBookings,
      },
      providers: {
        total: totalProviders,
        active: activeProviders,
        verified: verifiedProviders,
        pendingVerification: pendingProviders,
      },
      services: {
        topCategories,
      },
      emergencies: {
        activeRequests: activeEmergencyRequests,
        totalRequests: totalEmergencyRequests,
      },
      trust: {
        averageAcceptMinutes:
          acceptSample >= TRUST_RULES.acceptTimeMinSamples &&
          parsedAcceptMinutes != null &&
          Number.isFinite(parsedAcceptMinutes)
            ? Math.round(parsedAcceptMinutes)
            : null,
        sampleSize: acceptSample,
        windowDays: TRUST_RULES.acceptTimeWindowDays,
      },
    };
  }
}
