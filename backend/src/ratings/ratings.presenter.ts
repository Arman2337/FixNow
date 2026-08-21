import type {
  BookingReviewContract,
  ProviderRatingSummaryContract,
} from '../../../shared/ratings.types';
import type { BookingReview } from './domain/review.entity';

export const presentReview = (
  review: BookingReview,
): BookingReviewContract => ({
  id: review.id,
  bookingId: review.bookingId,
  rating: review.rating,
  reviewText: review.reviewText,
  moderationStatus: review.moderationStatus,
  createdAt: review.createdAt.toISOString(),
  updatedAt: review.updatedAt.toISOString(),
  version: review.version,
});

export const emptyProviderRating = (): ProviderRatingSummaryContract => ({
  averageRating: null,
  reviewCount: 0,
});
