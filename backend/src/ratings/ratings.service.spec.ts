import { ConflictException, ForbiddenException } from '@nestjs/common';
import type { DataSource, EntityManager, Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { ReviewModerationStatus } from '../../../shared/ratings.types';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingReview } from './domain/review.entity';
import { RatingsService } from './ratings.service';

describe('RatingsService', () => {
  const customerId = '00000000-0000-4000-8000-000000000001';
  const providerId = '00000000-0000-4000-8000-000000000002';
  const bookingId = '00000000-0000-4000-8000-000000000003';
  let bookingRepository: jest.Mocked<Repository<Booking>>;
  let reviewRepository: jest.Mocked<Repository<BookingReview>>;
  let service: RatingsService;

  const booking = (status = BookingStatus.COMPLETED): Booking =>
    Object.assign(new Booking(), {
      id: bookingId,
      customerId,
      providerId,
      status,
    });
  const review = (rating = 5): BookingReview =>
    Object.assign(new BookingReview(), {
      id: '00000000-0000-4000-8000-000000000004',
      bookingId,
      customerId,
      providerId,
      rating,
      reviewText: '<script>untrusted</script>',
      moderationStatus: ReviewModerationStatus.PUBLISHED,
      createdAt: new Date(),
      updatedAt: new Date(),
      version: 1,
    });

  beforeEach(() => {
    bookingRepository = { findOneBy: jest.fn() } as unknown as jest.Mocked<
      Repository<Booking>
    >;
    reviewRepository = {
      findOneBy: jest.fn(),
      find: jest.fn(),
      create: jest.fn<BookingReview, [Partial<BookingReview>]>((value) =>
        Object.assign(review(), value),
      ),
      save: jest.fn<Promise<BookingReview>, [BookingReview]>((value) =>
        Promise.resolve(value),
      ),
    } as unknown as jest.Mocked<Repository<BookingReview>>;
    const manager = {
      getRepository: jest.fn((entity: unknown) =>
        entity === Booking ? bookingRepository : reviewRepository,
      ),
    } as unknown as EntityManager;
    const dataSource = {
      getRepository: jest.fn((entity: unknown) =>
        entity === Booking ? bookingRepository : reviewRepository,
      ),
      transaction: jest.fn((callback: (value: EntityManager) => unknown) =>
        Promise.resolve(callback(manager)),
      ),
    } as unknown as DataSource;
    service = new RatingsService(dataSource);
  });

  it('allows only the completed booking owner and derives the provider from booking state', async () => {
    bookingRepository.findOneBy.mockResolvedValue(booking());
    reviewRepository.findOneBy.mockResolvedValue(null);
    const result = await service.createForCompletedBooking(
      bookingId,
      customerId,
      { rating: 5, reviewText: ' Great service ' },
    );
    expect(result.providerId).toBe(providerId);
    expect(result.customerId).toBe(customerId);
    expect(result.reviewText).toBe('Great service');
  });

  it.each([
    BookingStatus.REQUESTED,
    BookingStatus.ASSIGNED,
    BookingStatus.EN_ROUTE,
    BookingStatus.IN_PROGRESS,
    BookingStatus.CANCELLED,
  ])('rejects a %s booking', async (status) => {
    bookingRepository.findOneBy.mockResolvedValue(booking(status));
    await expect(
      service.createForCompletedBooking(bookingId, customerId, { rating: 5 }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects cross-customer review attempts and duplicate/concurrent review state', async () => {
    bookingRepository.findOneBy.mockResolvedValue(booking());
    await expect(
      service.createForCompletedBooking(
        bookingId,
        '00000000-0000-4000-8000-000000000099',
        { rating: 5 },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    reviewRepository.findOneBy.mockResolvedValue(review());
    await expect(
      service.createForCompletedBooking(bookingId, customerId, { rating: 5 }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('returns only published ratings in a deterministic aggregate and null/zero for a new provider', async () => {
    reviewRepository.find.mockResolvedValue([review(5), review(4)]);
    await expect(service.providerRatingFor(providerId)).resolves.toEqual({
      averageRating: 4.5,
      reviewCount: 2,
    });
    reviewRepository.find.mockResolvedValue([]);
    await expect(service.providerRatingFor(providerId)).resolves.toEqual({
      averageRating: null,
      reviewCount: 0,
    });
  });

  it('does not leak a review to a non-participant', async () => {
    bookingRepository.findOneBy.mockResolvedValue(booking());
    await expect(
      service.getForBooking(bookingId, '00000000-0000-4000-8000-000000000099'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
