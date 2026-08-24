import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { createHash } from 'crypto';
import { randomUUID } from 'crypto';
import { DataSource, Repository } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import {
  MALWARE_SCANNER,
  type MalwareScanner,
} from '../storage/malware-scanner';
import {
  PRIVATE_OBJECT_STORAGE,
  type PrivateObjectStorage,
} from '../storage/private-object-storage';
import { BookingReview } from './domain/review.entity';
import { ReviewPhoto, ReviewPhotoStatus } from './domain/review-photo.entity';
import { ReviewPhotoModerationEvent } from './domain/review-photo-moderation-event.entity';

export const REVIEW_PHOTO_LIMITS = {
  maxPhotosPerReview: 3,
  maxBytes: 5 * 1024 * 1024,
} as const;

const MIME_MAGIC: ReadonlyMap<string, (content: Buffer) => boolean> = new Map([
  [
    'image/jpeg',
    (c) => c.length >= 3 && c[0] === 0xff && c[1] === 0xd8 && c[2] === 0xff,
  ],
  [
    'image/png',
    (c) =>
      c.length >= 8 &&
      c[0] === 0x89 &&
      c[1] === 0x50 &&
      c[2] === 0x4e &&
      c[3] === 0x47,
  ],
  [
    'image/webp',
    (c) =>
      c.length >= 12 &&
      c.slice(0, 4).toString() === 'RIFF' &&
      c.slice(8, 12).toString() === 'WEBP',
  ],
]);

@Injectable()
export class ReviewPhotosService {
  constructor(
    @InjectRepository(BookingReview)
    private readonly reviews: Repository<BookingReview>,
    @InjectRepository(ReviewPhoto)
    private readonly photos: Repository<ReviewPhoto>,
    @InjectDataSource() private readonly dataSource: DataSource,
    @Inject(PRIVATE_OBJECT_STORAGE)
    private readonly storage: PrivateObjectStorage,
    @Inject(MALWARE_SCANNER) private readonly scanner: MalwareScanner,
  ) {}

  /**
   * FN-110: attach a bounded photo to an own review. Photos land in
   * quarantine, are malware-scanned, and stay moderation-pending until an
   * authorized reviewer approves them.
   */
  async attach(
    bookingId: string,
    customerId: string,
    contentType: string,
    content: Buffer,
  ): Promise<ReviewPhoto> {
    if (
      !MIME_MAGIC.has(contentType) ||
      content.length === 0 ||
      content.length > REVIEW_PHOTO_LIMITS.maxBytes
    ) {
      throw new BadRequestException('Unsupported or oversized review photo');
    }
    if (!MIME_MAGIC.get(contentType)!(content)) {
      throw new BadRequestException('Photo contents do not match its type');
    }
    const review = await this.reviews.findOneBy({ bookingId });
    if (!review || review.customerId !== customerId) {
      throw new NotFoundException('Review not found for this booking');
    }
    const existing = await this.photos.countBy({ reviewId: review.id });
    if (existing >= REVIEW_PHOTO_LIMITS.maxPhotosPerReview) {
      throw new ConflictException(
        `A review can hold at most ${REVIEW_PHOTO_LIMITS.maxPhotosPerReview} photos`,
      );
    }
    const objectKey = `quarantine/${randomUUID()}`;
    await this.storage.putQuarantined(objectKey, content, contentType);
    const verdict = await this.scanner.scan(content);
    if (verdict !== 'clean') {
      await this.storage.delete(objectKey);
      throw new BadRequestException('Photo failed security scanning');
    }
    return this.photos.save(
      this.photos.create({
        reviewId: review.id,
        uploadedBy: customerId,
        objectKey,
        contentType,
        sizeBytes: content.length,
        sha256: createHash('sha256').update(content).digest('hex'),
        status: ReviewPhotoStatus.PENDING,
      }),
    );
  }

  /**
   * Participant view. The author sees their own pending/rejected photos so
   * the UI can show honest states; the other participant sees approved
   * photos only.
   */
  async listForParticipants(
    bookingId: string,
    actorId: string,
  ): Promise<ReviewPhoto[]> {
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== actorId && booking.providerId !== actorId) {
      throw new ForbiddenException('You are not a participant of this booking');
    }
    const review = await this.reviews.findOneBy({ bookingId });
    if (!review) return [];
    const all = await this.photos.find({
      where: { reviewId: review.id },
      order: { createdAt: 'ASC' },
    });
    return all.filter(
      (photo) =>
        photo.status === ReviewPhotoStatus.APPROVED ||
        photo.uploadedBy === actorId,
    );
  }

  /** Permission-gated approve/reject with an immutable audit event. */
  async moderate(
    photoId: string,
    actorId: string,
    toStatus: Exclude<ReviewPhotoStatus, typeof ReviewPhotoStatus.PENDING>,
    reason: string,
  ): Promise<ReviewPhoto> {
    const normalizedReason = reason.trim();
    if (!normalizedReason || normalizedReason.length > 500) {
      throw new BadRequestException('A bounded moderation reason is required');
    }
    return this.dataSource.transaction(async (manager) => {
      const photos = manager.getRepository(ReviewPhoto);
      const events = manager.getRepository(ReviewPhotoModerationEvent);
      const photo = await photos.findOneBy({ id: photoId });
      if (!photo) throw new NotFoundException('Review photo not found');
      if (photo.status === toStatus) {
        throw new ConflictException('Photo already has this status');
      }
      const previous = photo.status;
      photo.status = toStatus;
      const saved = await photos.save(photo);
      await events.save(
        events.create({
          photoId,
          actorUserId: actorId,
          fromStatus: previous,
          toStatus,
          reason: normalizedReason,
        }),
      );
      return saved;
    });
  }

  present(photo: ReviewPhoto) {
    return {
      id: photo.id,
      status: photo.status,
      contentType: photo.contentType,
      sizeBytes: photo.sizeBytes,
      createdAt: photo.createdAt,
    };
  }
}
