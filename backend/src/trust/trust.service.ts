import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThan, Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { ReviewModerationStatus } from '../../../shared/ratings.types';
import {
  ProviderQualityMetricsContract,
  TrustSignalSeverity,
  TrustSignalStatus,
} from '../../../shared/trust.types';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingReview } from '../ratings/domain/review.entity';
import { Complaint } from '../support/complaints/domain/complaint.entity';
import { TrustSignal } from './domain/trust-signal.entity';

export const TRUST_RULES = {
  cancellationWindowDays: 30,
  cancellationThreshold: 3,
} as const;

@Injectable()
export class TrustService {
  constructor(
    @InjectRepository(Booking) private readonly bookings: Repository<Booking>,
    @InjectRepository(BookingReview)
    private readonly reviews: Repository<BookingReview>,
    @InjectRepository(Complaint)
    private readonly complaints: Repository<Complaint>,
    @InjectRepository(TrustSignal)
    private readonly signals: Repository<TrustSignal>,
  ) {}

  async providerMetrics(
    providerId: string,
  ): Promise<ProviderQualityMetricsContract> {
    const [bookings, reviews, complaintCount] = await Promise.all([
      this.bookings.find({ where: { providerId }, select: { status: true } }),
      this.reviews.find({
        where: {
          providerId,
          moderationStatus: ReviewModerationStatus.PUBLISHED,
        },
        select: { rating: true },
      }),
      this.complaints.count({ where: { targetId: providerId } }),
    ]);
    const completed = bookings.filter(
      (booking) => booking.status === BookingStatus.COMPLETED,
    ).length;
    const cancelled = bookings.filter(
      (booking) => booking.status === BookingStatus.CANCELLED,
    ).length;
    const terminal = completed + cancelled;
    const total = reviews.reduce((sum, review) => sum + review.rating, 0);
    return {
      completedBookingCount: completed,
      cancelledBookingCount: cancelled,
      completionRate:
        terminal === 0 ? null : Math.round((completed / terminal) * 1000) / 10,
      averageRating:
        reviews.length === 0
          ? null
          : Math.round((total / reviews.length) * 10) / 10,
      reviewCount: reviews.length,
      complaintCount,
    };
  }

  async evaluateCancellationSignal(
    providerId: string,
    now = new Date(),
  ): Promise<TrustSignal | null> {
    const windowStart = new Date(now);
    windowStart.setUTCDate(
      windowStart.getUTCDate() - TRUST_RULES.cancellationWindowDays,
    );
    const cancellations = await this.bookings.count({
      where: {
        providerId,
        status: BookingStatus.CANCELLED,
        cancelledAt: MoreThan(windowStart),
      },
    });
    if (cancellations < TRUST_RULES.cancellationThreshold) return null;
    const key = windowStart.toISOString().slice(0, 10);
    const existing = await this.signals.findOneBy({
      subjectType: 'PROVIDER',
      subjectId: providerId,
      ruleCode: 'provider-cancellation-frequency-v1',
      windowStart: key,
    });
    if (existing) return existing;
    return this.signals.save(
      this.signals.create({
        subjectType: 'PROVIDER',
        subjectId: providerId,
        ruleCode: 'provider-cancellation-frequency-v1',
        windowStart: key,
        severity: TrustSignalSeverity.LOW,
        evidenceSummary: `${cancellations} provider cancellations recorded in the last ${TRUST_RULES.cancellationWindowDays} days. Requires human review.`,
        status: TrustSignalStatus.OPEN,
        reviewedBy: null,
        reviewedAt: null,
      }),
    );
  }

  async listSignals(): Promise<TrustSignal[]> {
    return this.signals.find({ order: { createdAt: 'DESC' }, take: 100 });
  }
  async reviewSignal(
    id: string,
    actorId: string,
    status: TrustSignalStatus,
  ): Promise<TrustSignal> {
    const signal = await this.signals.findOneByOrFail({ id });
    signal.status = status;
    signal.reviewedBy = actorId;
    signal.reviewedAt = new Date();
    return this.signals.save(signal);
  }
}
