import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Inject,
} from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, MoreThan, Not, Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { ReviewModerationStatus } from '../../../shared/ratings.types';
import {
  ProviderAcceptTimeContract,
  ProviderQualityMetricsContract,
  TrustSignalSeverity,
  TrustSignalStatus,
  AppealStatus,
} from '../../../shared/trust.types';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingReview } from '../ratings/domain/review.entity';
import { Complaint } from '../support/complaints/domain/complaint.entity';
import { Refund } from '../payments/domain/refund.entity';
import { TrustSignal } from './domain/trust-signal.entity';

export const TRUST_RULES = {
  cancellationWindowDays: 30,
  cancellationThreshold: 3,
  complaintWindowDays: 30,
  complaintThreshold: 2,
  /** FN-060: customer-side cancellation pattern. */
  customerCancellationWindowDays: 30,
  customerCancellationThreshold: 3,
  /** FN-060: refunds recorded against one provider's bookings. */
  refundWindowDays: 30,
  refundThreshold: 2,
  /** FN-111: bounded rolling accept-time aggregate. */
  acceptTimeWindowDays: 90,
  acceptTimeMinSamples: 3,
  acceptTimeSampleCap: 100,
  acceptTimeCacheTtlMs: 300_000,
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
    @Inject(CACHE_MANAGER) private readonly cache: Cache,
    @InjectRepository(Refund)
    private readonly refunds: Repository<Refund>,
  ) {}

  /**
   * FN-111: explainable rolling mean of request→accept latency for one
   * provider, derived only from immutable lifecycle timestamps. Hidden
   * (null average) below the minimum sample size; never feeds matching.
   */
  async providerAcceptTime(
    providerId: string,
    now = new Date(),
  ): Promise<ProviderAcceptTimeContract> {
    const cacheKey = `trust:accept-time:${providerId}`;
    try {
      const cached = await this.cache.get<ProviderAcceptTimeContract>(cacheKey);
      if (cached) return cached;
    } catch {
      // Redis unavailable: compute fresh rather than failing the signal.
    }
    const windowStart = new Date(now);
    windowStart.setUTCDate(
      windowStart.getUTCDate() - TRUST_RULES.acceptTimeWindowDays,
    );
    const accepted = await this.bookings.find({
      where: {
        providerId,
        assignedAt: Not(IsNull()),
        createdAt: MoreThan(windowStart),
      },
      select: { createdAt: true, assignedAt: true },
      order: { assignedAt: 'DESC' },
      take: TRUST_RULES.acceptTimeSampleCap,
    });
    const latenciesMinutes = accepted
      .map(
        (booking) =>
          booking.assignedAt!.getTime() - booking.createdAt.getTime(),
      )
      .filter((milliseconds) => milliseconds >= 0)
      .map((milliseconds) => milliseconds / 60_000);
    const sufficient =
      latenciesMinutes.length >= TRUST_RULES.acceptTimeMinSamples;
    const contract: ProviderAcceptTimeContract = {
      averageAcceptMinutes: sufficient
        ? Math.round(
            latenciesMinutes.reduce((sum, value) => sum + value, 0) /
              latenciesMinutes.length,
          )
        : null,
      sampleSize: latenciesMinutes.length,
      windowDays: TRUST_RULES.acceptTimeWindowDays,
    };
    try {
      await this.cache.set(
        cacheKey,
        contract,
        TRUST_RULES.acceptTimeCacheTtlMs,
      );
    } catch {
      // Cache write failures are non-fatal; the next read recomputes.
    }
    return contract;
  }

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

  /**
   * FN-055/FN-060 shared shape for windowed-count review signals: one signal
   * per subject, rule, and day-bucketed window; purely advisory evidence
   * that always names its bounded window and requires human review.
   */
  private async recordWindowedSignal(input: {
    subjectType: TrustSignal['subjectType'];
    subjectId: string;
    ruleCode: string;
    severity: TrustSignalSeverity;
    windowDays: number;
    observedCount: number;
  }): Promise<TrustSignal | null> {
    const now = new Date();
    const key = now.toISOString().slice(0, 10);
    const existing = await this.signals.findOneBy({
      subjectType: input.subjectType,
      subjectId: input.subjectId,
      ruleCode: input.ruleCode,
      windowStart: key,
    });
    if (existing) return existing;
    return this.signals.save(
      this.signals.create({
        subjectType: input.subjectType,
        subjectId: input.subjectId,
        ruleCode: input.ruleCode,
        windowStart: key,
        severity: input.severity,
        evidenceSummary: `${input.observedCount} events matched rule ${input.ruleCode} in the last ${input.windowDays} days. Requires human review.`,
        status: TrustSignalStatus.OPEN,
        reviewedBy: null,
        reviewedAt: null,
      }),
    );
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
    return this.recordWindowedSignal({
      subjectType: 'PROVIDER',
      subjectId: providerId,
      ruleCode: 'provider-cancellation-frequency-v1',
      severity: TrustSignalSeverity.LOW,
      windowDays: TRUST_RULES.cancellationWindowDays,
      observedCount: cancellations,
    });
  }

  /**
   * FN-060: mirror of the provider rule on the customer side. Counts
   * cancellations of the customer's bookings without asserting who
   * initiated them; evidence stays factual for human review.
   */
  async evaluateCustomerCancellationSignal(
    customerId: string,
    now = new Date(),
  ): Promise<TrustSignal | null> {
    const windowStart = new Date(now);
    windowStart.setUTCDate(
      windowStart.getUTCDate() - TRUST_RULES.customerCancellationWindowDays,
    );
    const cancellations = await this.bookings.count({
      where: {
        customerId,
        status: BookingStatus.CANCELLED,
        cancelledAt: MoreThan(windowStart),
      },
    });
    if (cancellations < TRUST_RULES.customerCancellationThreshold) return null;
    return this.recordWindowedSignal({
      subjectType: 'CUSTOMER',
      subjectId: customerId,
      ruleCode: 'customer-cancellation-frequency-v1',
      severity: TrustSignalSeverity.LOW,
      windowDays: TRUST_RULES.customerCancellationWindowDays,
      observedCount: cancellations,
    });
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

  async evaluateComplaintSignal(
    providerId: string,
    now = new Date(),
  ): Promise<TrustSignal | null> {
    const windowStart = new Date(now);
    windowStart.setUTCDate(
      windowStart.getUTCDate() - TRUST_RULES.complaintWindowDays,
    );
    const complaintsCount = await this.complaints.count({
      where: {
        targetId: providerId,
        createdAt: MoreThan(windowStart),
      },
    });
    if (complaintsCount < TRUST_RULES.complaintThreshold) return null;
    return this.recordWindowedSignal({
      subjectType: 'PROVIDER',
      subjectId: providerId,
      ruleCode: 'provider-complaint-frequency-v1',
      severity: TrustSignalSeverity.MEDIUM,
      windowDays: TRUST_RULES.complaintWindowDays,
      observedCount: complaintsCount,
    });
  }

  /**
   * FN-060: refunds recorded against one provider's bookings. Refunds are
   * staff-controlled (FN-053); a cluster may indicate quality or dispute
   * problems and always routes to human review.
   */
  async evaluateProviderRefundSignal(
    providerId: string,
    now = new Date(),
  ): Promise<TrustSignal | null> {
    const windowStart = new Date(now);
    windowStart.setUTCDate(
      windowStart.getUTCDate() - TRUST_RULES.refundWindowDays,
    );
    const refundCount = await this.refunds
      .createQueryBuilder('refund')
      .innerJoin(
        'payment_orders',
        'order',
        'order.id = refund.payment_order_id',
      )
      .innerJoin('bookings', 'booking', 'booking.id = order.booking_id')
      .where('booking.provider_id = :providerId', { providerId })
      .andWhere('refund.status = :status', { status: 'PROCESSED' })
      .andWhere('refund.created_at > :windowStart', { windowStart })
      .getCount();
    if (refundCount < TRUST_RULES.refundThreshold) return null;
    return this.recordWindowedSignal({
      subjectType: 'PROVIDER',
      subjectId: providerId,
      ruleCode: 'provider-refund-frequency-v1',
      severity: TrustSignalSeverity.MEDIUM,
      windowDays: TRUST_RULES.refundWindowDays,
      observedCount: refundCount,
    });
  }

  async submitSignalAppeal(
    id: string,
    actorId: string,
    reason: string,
  ): Promise<TrustSignal> {
    const signal = await this.signals.findOneBy({ id });
    if (!signal) {
      throw new NotFoundException(`Trust signal with ID ${id} not found`);
    }

    if (signal.subjectId !== actorId) {
      throw new ForbiddenException(
        'Only the subject can appeal this trust signal',
      );
    }

    signal.appealStatus = AppealStatus.PENDING;
    signal.appealReason = reason;
    return this.signals.save(signal);
  }
}
