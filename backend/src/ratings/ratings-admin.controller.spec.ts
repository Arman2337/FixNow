import { RatingsAdminController } from './ratings-admin.controller';
import { RatingsService } from './ratings.service';
import { ReviewPhotosService } from './review-photos.service';
import { PATH_METADATA } from '@nestjs/common/constants';
import { ReviewModerationStatus } from '../../../shared/ratings.types';

describe('RatingsAdminController', () => {
  let controller: RatingsAdminController;
  let ratingsService: jest.Mocked<RatingsService>;
  let photosService: jest.Mocked<ReviewPhotosService>;

  const req = {
    authorizationPrincipal: {
      userId: 'admin-usr-1',
      role: 'trust_safety_reviewer',
    },
  } as any;

  beforeEach(() => {
    ratingsService = {
      moderate: jest.fn(),
    } as unknown as jest.Mocked<RatingsService>;

    photosService = {
      moderate: jest.fn(),
      present: jest.fn((p) => ({ id: p.id, status: p.status })),
    } as unknown as jest.Mocked<ReviewPhotosService>;

    controller = new RatingsAdminController(ratingsService, photosService);
  });

  describe('Route shadowing guard (GAP-04)', () => {
    it('declares photos/:photoId/moderation before :id/moderation so Express does not bind "photos" to :id', () => {
      const prototype = RatingsAdminController.prototype;
      const methods = Object.getOwnPropertyNames(prototype).filter(
        (prop) =>
          typeof (prototype as any)[prop] === 'function' &&
          prop !== 'constructor',
      );

      const photoModIndex = methods.indexOf('moderatePhoto');
      const reviewModIndex = methods.indexOf('moderate');

      expect(photoModIndex).toBeGreaterThanOrEqual(0);
      expect(reviewModIndex).toBeGreaterThanOrEqual(0);
      expect(photoModIndex).toBeLessThan(reviewModIndex);

      const photoPath = Reflect.getMetadata(
        PATH_METADATA,
        prototype.moderatePhoto,
      );
      const reviewPath = Reflect.getMetadata(PATH_METADATA, prototype.moderate);

      expect(photoPath).toBe('photos/:photoId/moderation');
      expect(reviewPath).toBe(':id/moderation');
    });
  });

  describe('moderatePhoto', () => {
    it('moderates a review photo and returns presented payload', async () => {
      const mockPhoto = { id: 'photo-123', status: 'APPROVED' } as any;
      photosService.moderate.mockResolvedValue(mockPhoto);

      const result = await controller.moderatePhoto('photo-123', req, {
        status: 'APPROVED',
        reason: 'Verified genuine proof',
      });

      expect(photosService.moderate).toHaveBeenCalledWith(
        'photo-123',
        'admin-usr-1',
        'APPROVED',
        'Verified genuine proof',
      );
      expect(result).toEqual({
        photo: { id: 'photo-123', status: 'APPROVED' },
      });
    });
  });

  describe('moderate', () => {
    it('moderates a review text/rating and returns presented review', async () => {
      const mockReview = {
        id: 'rev-456',
        bookingId: 'booking-789',
        rating: 5,
        reviewText: 'Great service',
        moderationStatus: ReviewModerationStatus.PUBLISHED,
        createdAt: new Date(),
        updatedAt: new Date(),
        version: 1,
        moderatedAt: new Date(),
        moderatedByUserId: 'admin-usr-1',
        moderationReason: 'Policy compliant',
      } as any;
      ratingsService.moderate.mockResolvedValue(mockReview);

      const result = await controller.moderate('rev-456', req, {
        moderationStatus: ReviewModerationStatus.PUBLISHED,
        reason: 'Policy compliant',
      });

      expect(ratingsService.moderate).toHaveBeenCalledWith(
        'rev-456',
        'admin-usr-1',
        ReviewModerationStatus.PUBLISHED,
        'Policy compliant',
      );
      expect(result.review).toBeDefined();
      expect(result.review.id).toBe('rev-456');
    });
  });
});
