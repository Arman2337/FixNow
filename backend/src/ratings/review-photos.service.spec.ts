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
