import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { ReviewPhoto, ReviewPhotoStatus } from './domain/review-photo.entity';
import { ReviewPhotosService } from './review-photos.service';

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);

describe('ReviewPhotosService', () => {
  const customerId = '00000000-0000-4000-8000-00000000000a';
  const providerId = '00000000-0000-4000-8000-00000000000b';

  const reviews = { findOneBy: jest.fn() };
  const photosRepo = {
    findOneBy: jest.fn(),
    countBy: jest.fn().mockResolvedValue(0),
    find: jest.fn().mockResolvedValue([]),
    create: jest.fn(<T extends object>(value: T): T => value),
    save: jest.fn((value) => Promise.resolve({ id: 'photo-1', ...value })),
  };
  const eventsRepo = {
    create: jest.fn(<T extends object>(value: T): T => value),
    save: jest.fn((value) => Promise.resolve(value)),
  };
  const storage = {
    putQuarantined: jest.fn().mockResolvedValue(undefined),
    readPrivate: jest.fn(),
    delete: jest.fn().mockResolvedValue(undefined),
  };
  const scanner = { scan: jest.fn().mockResolvedValue('clean') };
  const bookingRepo = { findOneBy: jest.fn() };

  const dataSource = {
    getRepository: jest.fn(() => bookingRepo),
    transaction: jest.fn(<T>(callback: (manager: unknown) => T): Promise<T> =>
      Promise.resolve(
        callback({
          getRepository: (entity: unknown) =>
            entity === ReviewPhoto ? photosRepo : eventsRepo,
        }),
      ),
    ),
  };

  const service = new ReviewPhotosService(
    reviews as never,
    photosRepo as never,
    dataSource as never,
    storage,
    scanner,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    photosRepo.countBy.mockResolvedValue(0);
    scanner.scan.mockResolvedValue('clean');
    reviews.findOneBy.mockResolvedValue({
      id: 'review-1',
      bookingId: 'booking-1',
      customerId,
      providerId,
    });
  });

  describe('attach', () => {
    it('stores a scanned photo in moderation-pending quarantine', async () => {
      const photo = await service.attach(
        'booking-1',
        customerId,
        'image/jpeg',
        JPEG,
      );
      expect(photo.status).toBe(ReviewPhotoStatus.PENDING);
      expect(storage.putQuarantined).toHaveBeenCalledWith(
        expect.stringContaining('quarantine/'),
        JPEG,
        'image/jpeg',
      );
      expect(scanner.scan).toHaveBeenCalledWith(JPEG);
      expect(photo.sha256).toHaveLength(64);
    });

    it('rejects unsupported or mismatched content types without storing', async () => {
      await expect(
        service.attach('booking-1', customerId, 'application/pdf', JPEG),
      ).rejects.toBeInstanceOf(BadRequestException);
      await expect(
        service.attach('booking-1', customerId, 'image/png', JPEG),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(storage.putQuarantined).not.toHaveBeenCalled();
    });

    it('rejects oversized photos', async () => {
      await expect(
        service.attach(
          'booking-1',
          customerId,
          'image/jpeg',
          Buffer.concat([
            Buffer.from([0xff, 0xd8, 0xff]),
            Buffer.alloc(5 * 1024 * 1024),
          ]),
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('deletes and rejects a photo flagged by the malware scan', async () => {
      scanner.scan.mockResolvedValue('dirty');
      await expect(
        service.attach('booking-1', customerId, 'image/jpeg', JPEG),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(storage.delete).toHaveBeenCalled();
      expect(photosRepo.save).not.toHaveBeenCalled();
    });

    it('caps photos per review at three', async () => {
      photosRepo.countBy.mockResolvedValue(3);
      await expect(
        service.attach('booking-1', customerId, 'image/jpeg', JPEG),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('only the review author can attach', async () => {
      await expect(
        service.attach('booking-1', providerId, 'image/jpeg', JPEG),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('listForParticipants', () => {
    const photo = (status: string, uploadedBy = customerId) => ({
      id: `photo-${status}-${uploadedBy}`,
      status,
      uploadedBy,
    });

    it('shows approved photos to both participants plus own pending ones', async () => {
      bookingRepo.findOneBy.mockResolvedValue({
        id: 'booking-1',
        customerId,
        providerId,
      });
      photosRepo.find.mockResolvedValue([
        photo('APPROVED'),
        photo('PENDING'),
        photo('REJECTED'),
      ]);

      for (const actor of [customerId, providerId]) {
        const rows = await service.listForParticipants('booking-1', actor);
        expect(rows.some((row) => row.status === 'APPROVED')).toBe(true);
        if (actor === customerId) {
          expect(rows).toHaveLength(3); // author sees honest pending/rejected
        } else {
          expect(rows).toHaveLength(1); // others see approved only
        }
      }
    });

    it('refuses non-participants', async () => {
      bookingRepo.findOneBy.mockResolvedValue({
        id: 'booking-1',
        customerId,
        providerId,
      });
      await expect(
        service.listForParticipants('booking-1', 'someone-else'),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('readPhoto (FN-144)', () => {
    const stored = (
      id: string,
      status: string,
      uploadedBy: string,
    ): ReviewPhoto =>
      ({
        id,
        status,
        uploadedBy,
        objectKey: `quarantine/${id}`,
        contentType: 'image/jpeg',
      }) as ReviewPhoto;

    beforeEach(() => {
      bookingRepo.findOneBy.mockResolvedValue({
        id: 'booking-1',
        customerId,
        providerId,
      });
      storage.readPrivate.mockResolvedValue(JPEG);
      // Faithful to the real lookup chain — booking -> its review -> that
      // review's photos — so a test asking about another booking really does
      // see an empty photo set rather than the mocked one leaking across.
      reviews.findOneBy.mockImplementation(
        ({ bookingId }: { bookingId: string }) =>
          Promise.resolve({ id: `review-${bookingId}` }) as never,
      );
      photosRepo.find.mockImplementation(
        ({ where }: { where: { reviewId: string } }) =>
          Promise.resolve(
            where.reviewId === 'review-booking-1'
              ? [
                  {
                    id: 'p5',
                    status: 'APPROVED',
                    uploadedBy: customerId,
                    objectKey: 'quarantine/p5',
                    contentType: 'image/jpeg',
                  },
                ]
              : [],
          ) as never,
      );
    });

    it('streams an approved photo to the other participant', async () => {
      photosRepo.find.mockResolvedValue([stored('p1', 'APPROVED', customerId)]);

      const result = await service.readPhoto('booking-1', 'p1', providerId);

      expect(result.content).toEqual(JPEG);
      expect(storage.readPrivate).toHaveBeenCalledWith('quarantine/p1');
    });

    it('streams the author their own pending photo', async () => {
      photosRepo.find.mockResolvedValue([stored('p2', 'PENDING', customerId)]);

      const result = await service.readPhoto('booking-1', 'p2', customerId);

      expect(result.content).toEqual(JPEG);
    });

    it('refuses a pending photo to the participant who may not see it yet', async () => {
      // Reading through the participant-visible set rather than by bare id is
      // what stops a guessed photo id from bypassing moderation.
      photosRepo.find.mockResolvedValue([stored('p3', 'PENDING', customerId)]);

      await expect(
        service.readPhoto('booking-1', 'p3', providerId),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(storage.readPrivate).not.toHaveBeenCalled();
    });

    it('refuses a rejected photo to the other participant', async () => {
      photosRepo.find.mockResolvedValue([stored('p4', 'REJECTED', customerId)]);

      await expect(
        service.readPhoto('booking-1', 'p4', providerId),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(storage.readPrivate).not.toHaveBeenCalled();
    });

    it('refuses a photo belonging to another booking', async () => {
      await expect(
        service.readPhoto('booking-2', 'p5', customerId),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(storage.readPrivate).not.toHaveBeenCalled();
    });

    it('refuses a non-participant before touching storage', async () => {
      await expect(
        service.readPhoto('booking-1', 'p1', 'a-stranger'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(storage.readPrivate).not.toHaveBeenCalled();
    });
  });

  describe('moderate', () => {
    it('records an immutable moderation event with the reason', async () => {
      photosRepo.findOneBy.mockResolvedValue({
        id: 'photo-1',
        status: ReviewPhotoStatus.PENDING,
      });
      const saved = await service.moderate(
        'photo-1',
        'admin-1',
        'APPROVED',
        'Legitimate damage evidence.',
      );
      expect(saved.status).toBe('APPROVED');
      expect(eventsRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          photoId: 'photo-1',
          fromStatus: 'PENDING',
          toStatus: 'APPROVED',
          reason: 'Legitimate damage evidence.',
        }),
      );
    });

    it.each(['   ', 'x'.repeat(501)])(
      'requires a bounded non-empty reason (%s)',
      async (reason) => {
        await expect(
          service.moderate('photo-1', 'admin-1', 'REJECTED', reason),
        ).rejects.toBeInstanceOf(BadRequestException);
      },
    );

    it('refuses re-applying the same status', async () => {
      photosRepo.findOneBy.mockResolvedValue({
        id: 'photo-1',
        status: ReviewPhotoStatus.APPROVED,
      });
      await expect(
        service.moderate('photo-1', 'admin-1', 'APPROVED', 'reason'),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });
});
