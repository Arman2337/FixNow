import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { ProviderOnboardingStatus } from '../providers/provider-onboarding-status';

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
}

@Injectable()
export class AdminAnalyticsService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookings: Repository<Booking>,
    @InjectRepository(ProviderApplicationEntity)
    private readonly applications: Repository<ProviderApplicationEntity>,
    @InjectRepository(ServiceCategoryEntity)
    private readonly services: Repository<ServiceCategoryEntity>,
  ) {}

  async getOperationalAnalytics(): Promise<AnalyticsResponse> {
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
    };
  }
}
