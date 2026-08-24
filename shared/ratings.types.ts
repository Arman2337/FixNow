export enum ReviewModerationStatus {
  PUBLISHED = 'PUBLISHED',
  HIDDEN = 'HIDDEN',
  FLAGGED = 'FLAGGED',
}

export interface CreateReviewRequest {
  rating: number;
  reviewText?: string;
}

export interface BookingReviewContract {
  id: string;
  bookingId: string;
  rating: number;
  reviewText: string | null;
  moderationStatus: ReviewModerationStatus;
  createdAt: string;
  updatedAt: string;
  version: number;
}

export interface ProviderRatingSummaryContract {
  averageRating: number | null;
  reviewCount: number;
}

export interface BookingReviewResponse {
  review: BookingReviewContract | null;
  providerRating: ProviderRatingSummaryContract | null;
}
