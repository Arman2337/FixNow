import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, QueryFailedError } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import {
  ProviderRatingSummaryContract,
  ReviewModerationStatus,
} from '../../../shared/ratings.types';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingReview } from './domain/review.entity';
import { ReviewModerationEvent } from './domain/review-moderation-event.entity';
import { CreateReviewDto } from './ratings.dto';
import { emptyProviderRating } from './ratings.presenter';

@Injectable()
export class RatingsService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async createForCompletedBooking(
    bookingId: string,
    customerId: string,
    input: CreateReviewDto,
  ): Promise<BookingReview> {
    const reviewText = input.reviewText?.trim() || null;
    try {
      return await this.dataSource.transaction(async (manager) => {
        const bookings = manager.getRepository(Booking);
        const reviews = manager.getRepository(BookingReview);
        const booking = await bookings.findOneBy({ id: bookingId });
        this.assertEligible(booking, customerId);

        const existing = await reviews.findOneBy({ bookingId });
        if (existing)
          throw new ConflictException('This booking is already reviewed');

        return reviews.save(
          reviews.create({
            bookingId: booking.id,
            customerId: booking.customerId,
            providerId: booking.providerId!,
            rating: input.rating,
            reviewText,
            moderationStatus: ReviewModerationStatus.PUBLISHED,
          }),
        );
      });
    } catch (error: unknown) {
      if (!this.isUniqueViolation(error)) throw error;
      throw new ConflictException('This booking is already reviewed');
    }
  }

  async getForBooking(
    bookingId: string,
    actorId: string,
  ): Promise<BookingReview | null> {
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== actorId && booking.providerId !== actorId) {
      throw new ForbiddenException(
        'You are not authorized to view this review',
      );
    }
    return this.dataSource
      .getRepository(BookingReview)
      .findOneBy({ bookingId });
  }

  async providerRatingFor(
    providerId: string,
  ): Promise<ProviderRatingSummaryContract> {
    const reviews = await this.dataSource.getRepository(BookingReview).find({
      where: { providerId, moderationStatus: ReviewModerationStatus.PUBLISHED },
      select: { rating: true },
    });
    if (reviews.length === 0) return emptyProviderRating();
    const total = reviews.reduce((sum, review) => sum + review.rating, 0);
    return {
      averageRating: Math.round((total / reviews.length) * 10) / 10,
      reviewCount: reviews.length,
    };
  }

  async moderate(
    reviewId: string,
    actorId: string,
    moderationStatus: ReviewModerationStatus,
    reason: string,
  ): Promise<BookingReview> {
    const normalizedReason = reason.trim();
    if (!normalizedReason)
      throw new ConflictException('A moderation reason is required');
    return this.dataSource.transaction(async (manager) => {
      const reviews = manager.getRepository(BookingReview);
      const events = manager.getRepository(ReviewModerationEvent);
      const review = await reviews.findOneBy({ id: reviewId });
      if (!review) throw new NotFoundException('Review not found');
      if (review.moderationStatus === moderationStatus)
        throw new ConflictException(
          'Review already has this moderation status',
        );
      const previous = review.moderationStatus;
      review.moderationStatus = moderationStatus;
      const saved = await reviews.save(review);
      await events.save(
        events.create({
          reviewId,
          actorUserId: actorId,
          fromStatus: previous,
          toStatus: moderationStatus,
          reason: normalizedReason,
        }),
      );
      return saved;
    });
  }

  private assertEligible(
    booking: Booking | null,
    customerId: string,
  ): asserts booking is Booking {
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== customerId)
      throw new ForbiddenException('You do not own this booking');
    if (booking.status !== BookingStatus.COMPLETED || !booking.providerId) {
      throw new ConflictException(
        'Only completed bookings with an assigned provider can be reviewed',
      );
    }
  }

  private isUniqueViolation(error: unknown): boolean {
    if (!(error instanceof QueryFailedError)) return false;
    return (error.driverError as { code?: unknown }).code === '23505';
  }
}
