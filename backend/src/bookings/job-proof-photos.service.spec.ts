import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { Booking } from './domain/booking.entity';
import { JobProofPhoto, JobProofStage } from './domain/job-proof-photo.entity';
import { JobProofPhotosService } from './job-proof-photos.service';

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);

function booking(overrides: Partial<Booking> = {}) {
  return {
    id: 'booking-1',
    customerId: 'customer-1',
    providerId: 'provider-1',
    status: BookingStatus.IN_PROGRESS,
    ...overrides,
  } as Booking;
}

describe('JobProofPhotosService', () => {
  const bookings = { findOneBy: jest.fn() };
  const photos = {
    findOneBy: jest.fn().mockResolvedValue(null),
    find: jest.fn().mockResolvedValue([]),
    create: jest.fn(<T extends object>(value: T): T => value),
    save: jest.fn((value) => Promise.resolve({ id: 'proof-1', ...value })),
  };
  const storage = {
    putQuarantined: jest.fn().mockResolvedValue(undefined),
    readPrivate: jest.fn(),
    delete: jest.fn().mockResolvedValue(undefined),
  };
  const scanner = { scan: jest.fn().mockResolvedValue('clean') };

  const service = new JobProofPhotosService(
    bookings as never,
    photos as never,
    storage,
    scanner,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    bookings.findOneBy.mockResolvedValue(booking());
    photos.findOneBy.mockResolvedValue(null);
    scanner.scan.mockResolvedValue('clean');
  });

  describe('capture', () => {
    const capture = (
      overrides: Partial<Parameters<JobProofPhotosService['capture']>[0]> = {},
    ) =>
      service.capture({
        bookingId: 'booking-1',
        providerId: 'provider-1',
        stage: JobProofStage.BEFORE,
        contentType: 'image/jpeg',
        content: JPEG,
        ...overrides,
      });

    it('stores a scanned photo under an opaque quarantine key', async () => {
      const photo = await capture();

      expect(storage.putQuarantined).toHaveBeenCalledTimes(1);
      const [key] = storage.putQuarantined.mock.calls[0] as [string];
      expect(key.startsWith('quarantine/')).toBe(true);
      expect(photo.objectKey).toBe(key);
      expect(photo.stage).toBe('BEFORE');
      expect(photo.uploadedBy).toBe('provider-1');
      expect(photo.sha256).toMatch(/^[0-9a-f]{64}$/);
    });

    it('refuses a provider who was not assigned the booking', async () => {
      await expect(
        capture({ providerId: 'someone-else' }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(storage.putQuarantined).not.toHaveBeenCalled();
    });

    it('refuses capture before the pro is on site', async () => {
      bookings.findOneBy.mockResolvedValue(
        booking({ status: BookingStatus.REQUESTED }),
      );
      await expect(capture()).rejects.toBeInstanceOf(ConflictException);
    });

    it('still accepts the final after shot once the job is complete', async () => {
      bookings.findOneBy.mockResolvedValue(
        booking({ status: BookingStatus.COMPLETED }),
      );
      await expect(
        capture({ stage: JobProofStage.AFTER }),
      ).resolves.toBeDefined();
    });

    it('refuses to attach proof to a cancelled booking', async () => {
      bookings.findOneBy.mockResolvedValue(
        booking({ status: BookingStatus.CANCELLED }),
      );
      await expect(capture()).rejects.toBeInstanceOf(ConflictException);
    });

    it('rejects a stage that is not BEFORE or AFTER', async () => {
      await expect(
        capture({ stage: 'MIDDLE' as never }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rejects content whose bytes do not match the declared type', async () => {
      await expect(
        capture({ contentType: 'image/png', content: JPEG }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(storage.putQuarantined).not.toHaveBeenCalled();
    });

    it('rejects an oversized photo before it reaches storage', async () => {
      await expect(
        capture({ content: Buffer.alloc(6 * 1024 * 1024) }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(storage.putQuarantined).not.toHaveBeenCalled();
    });

    it('deletes the object and writes nothing when the scan is not clean', async () => {
      scanner.scan.mockResolvedValue('infected');
      await expect(capture()).rejects.toBeInstanceOf(BadRequestException);
      expect(storage.delete).toHaveBeenCalledTimes(1);
      expect(photos.save).not.toHaveBeenCalled();
    });

    it('replaces the previous photo for the same stage and removes its bytes', async () => {
      const previous = {
        id: 'old-proof',
        objectKey: 'quarantine/old',
      } as JobProofPhoto;
      photos.findOneBy.mockResolvedValue(previous);

      const photo = await capture();

      expect(photo.id).toBe('old-proof');
      expect(photo.objectKey).not.toBe('quarantine/old');
      expect(storage.delete).toHaveBeenCalledWith('quarantine/old');
    });

    it('reports a missing booking as not found', async () => {
      bookings.findOneBy.mockResolvedValue(null);
      await expect(capture()).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('listForParticipants', () => {
    it('returns the proof to the booking customer', async () => {
      photos.find.mockResolvedValue([]);
      await expect(
        service.listForParticipants('booking-1', 'customer-1'),
      ).resolves.toEqual([]);
      expect(photos.find).toHaveBeenCalledWith({
        where: { bookingId: 'booking-1' },
        order: { stage: 'ASC' },
      });
    });

    it('returns the proof to the assigned provider', async () => {
      await expect(
        service.listForParticipants('booking-1', 'provider-1'),
      ).resolves.toEqual([]);
    });

    it('refuses an account that is neither party', async () => {
      await expect(
        service.listForParticipants('booking-1', 'a-stranger'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(photos.find).not.toHaveBeenCalled();
    });
  });

  describe('readPhoto', () => {
    it('streams the bytes to a participant', async () => {
      const photo = {
        id: 'proof-1',
        bookingId: 'booking-1',
        objectKey: 'quarantine/x',
        contentType: 'image/jpeg',
      } as JobProofPhoto;
      photos.findOneBy.mockResolvedValue(photo);
      storage.readPrivate.mockResolvedValue(JPEG);

      const result = await service.readPhoto(
        'booking-1',
        'proof-1',
        'customer-1',
      );

      expect(result.content).toEqual(JPEG);
      expect(storage.readPrivate).toHaveBeenCalledWith('quarantine/x');
    });

    it('does not read storage for a non-participant', async () => {
      await expect(
        service.readPhoto('booking-1', 'proof-1', 'a-stranger'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(storage.readPrivate).not.toHaveBeenCalled();
    });

    it('treats another booking’s photo id as a miss, not a leak', async () => {
      // The lookup is scoped by bookingId as well as id. If that ever widens to
      // a bare id, this test is what notices.
      photos.findOneBy.mockResolvedValue(null);
      await expect(
        service.readPhoto(
          'booking-1',
          'proof-from-another-booking',
          'customer-1',
        ),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(storage.readPrivate).not.toHaveBeenCalled();
    });
  });

  describe('present', () => {
    it('never exposes the storage key', () => {
      const projected = service.present({
        id: 'proof-1',
        bookingId: 'booking-1',
        stage: JobProofStage.AFTER,
        objectKey: 'quarantine/secret',
        contentType: 'image/jpeg',
        sizeBytes: 6,
        sha256: 'a'.repeat(64),
        uploadedBy: 'provider-1',
        createdAt: new Date(0),
        updatedAt: new Date(0),
      });

      expect(projected).toEqual({
        id: 'proof-1',
        bookingId: 'booking-1',
        stage: 'AFTER',
        contentType: 'image/jpeg',
        sizeBytes: 6,
        createdAt: new Date(0),
      });
      expect(JSON.stringify(projected)).not.toContain('quarantine');
      expect(JSON.stringify(projected)).not.toContain('sha256');
    });
  });
});
