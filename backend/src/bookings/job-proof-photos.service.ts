import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash, randomUUID } from 'crypto';
import { Repository } from 'typeorm';
import { Booking } from './domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { JobProofPhoto, JobProofStage } from './domain/job-proof-photo.entity';
import {
  MALWARE_SCANNER,
  type MalwareScanner,
} from '../storage/malware-scanner';
import {
  PRIVATE_OBJECT_STORAGE,
  type PrivateObjectStorage,
} from '../storage/private-object-storage';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import {
  assertOwnedByParty,
  assertOwnedResource,
} from '../common/authorization/resource-ownership';

export const JOB_PROOF_LIMITS = {
  maxBytes: 5 * 1024 * 1024,
} as const;

/**
 * On-site only. A provider may still attach the final "after" shot once the
 * job is complete, because the work is finished by then and deleting the
 * customer's evidence because the status flipped would be worse than allowing
 * the upload. REQUESTED is refused because nobody is on site yet, and
 * CANCELLED because there is no job to prove.
 */
export const JOB_PROOF_CAPTURABLE_STATUSES: readonly BookingStatus[] = [
  BookingStatus.ASSIGNED,
  BookingStatus.EN_ROUTE,
  BookingStatus.IN_PROGRESS,
  BookingStatus.COMPLETED,
];

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

export function isJobProofStage(value: unknown): value is JobProofStage {
  return value === JobProofStage.BEFORE || value === JobProofStage.AFTER;
}

@Injectable()
export class JobProofPhotosService {
  constructor(
    @InjectRepository(Booking) private readonly bookings: Repository<Booking>,
    @InjectRepository(JobProofPhoto)
    private readonly photos: Repository<JobProofPhoto>,
    @Inject(PRIVATE_OBJECT_STORAGE)
    private readonly storage: PrivateObjectStorage,
    @Inject(MALWARE_SCANNER) private readonly scanner: MalwareScanner,
  ) {}

  /**
   * FN-142: capture the before or after shot for a booking.
   *
   * Exactly one photo per (booking, stage). Re-capturing a stage replaces the
   * previous photo, which is the behaviour a provider expects when they
   * retake a blurry shot — and it keeps the customer's slider from having to
   * choose between several "before" images.
   */
  async capture(input: {
    bookingId: string;
    providerId: string;
    stage: JobProofStage;
    contentType: string;
    content: Buffer;
    principal?: AuthorizationPrincipal;
  }): Promise<JobProofPhoto> {
    if (!isJobProofStage(input.stage)) {
      throw new BadRequestException(
        'A job proof stage must be BEFORE or AFTER',
      );
    }
    if (
      !MIME_MAGIC.has(input.contentType) ||
      input.content.length === 0 ||
      input.content.length > JOB_PROOF_LIMITS.maxBytes
    ) {
      throw new BadRequestException('Unsupported or oversized job proof photo');
    }
    if (!MIME_MAGIC.get(input.contentType)!(input.content)) {
      throw new BadRequestException('Photo contents do not match its type');
    }

    const booking = await this.bookings.findOneBy({ id: input.bookingId });
    if (!booking) throw new NotFoundException('Booking not found');
    // Not "customerId === providerId". A proof only means something if the
    // pro who took it is the pro who did the work.
    if (booking.providerId !== input.providerId) {
      throw new ForbiddenException(
        'Only the assigned provider can attach job proof',
      );
    }
    if (!JOB_PROOF_CAPTURABLE_STATUSES.includes(booking.status)) {
      throw new ConflictException(
        `Job proof can only be captured during an active or completed service (${JOB_PROOF_CAPTURABLE_STATUSES.join(', ')})`,
      );
    }
    if (input.principal) {
      assertOwnedResource(
        input.principal,
        booking.providerId,
        'booking.providerId',
      );
    }

    const existing = await this.photos.findOneBy({
      bookingId: booking.id,
      stage: input.stage,
    });
    const objectKey = `quarantine/${randomUUID()}`;
    await this.storage.putQuarantined(
      objectKey,
      input.content,
      input.contentType,
    );
    const verdict = await this.scanner.scan(input.content);
    if (verdict !== 'clean') {
      await this.storage.delete(objectKey);
      throw new BadRequestException('Photo failed security scanning');
    }

    const saved = await this.photos.save(
      this.photos.create({
        ...(existing ?? {}),
        id: existing?.id,
        bookingId: booking.id,
        stage: input.stage,
        uploadedBy: input.providerId,
        objectKey,
        contentType: input.contentType,
        sizeBytes: input.content.length,
        sha256: createHash('sha256').update(input.content).digest('hex'),
      }),
    );
    // The replaced photo is now unreachable from any row. Left in storage it
    // would be an orphan the customer can still be shown if the key ever leaks.
    if (existing) await this.storage.delete(existing.objectKey);
    return saved;
  }

  /** Participant view: the customer and the assigned provider. */
  async listForParticipants(
    bookingId: string,
    actorId: string,
    principal?: AuthorizationPrincipal,
  ): Promise<JobProofPhoto[]> {
    await this.assertParticipant(bookingId, actorId, principal);
    return this.photos.find({
      where: { bookingId },
      order: { stage: 'ASC' },
    });
  }

  /**
   * Bytes for one photo, for a booking participant only.
   *
   * This endpoint is the reason the table exists in a useful form: the review
   * photo pipeline stores approved images that no client can actually fetch,
   * because its projection carries no image reference. Here the reference stays
   * server-side and the client is handed the bytes.
   */
  async readPhoto(
    bookingId: string,
    photoId: string,
    actorId: string,
    principal?: AuthorizationPrincipal,
  ): Promise<{ metadata: JobProofPhoto; content: Buffer }> {
    await this.assertParticipant(bookingId, actorId, principal);
    const photo = await this.photos.findOneBy({ id: photoId, bookingId });
    // Scoped by bookingId as well as id, so a valid photo id belonging to
    // somebody else's booking is a miss rather than a leak.
    if (!photo) throw new NotFoundException('Job proof photo not found');
    return {
      metadata: photo,
      content: await this.storage.readPrivate(photo.objectKey),
    };
  }

  private async assertParticipant(
    bookingId: string,
    actorId: string,
    principal?: AuthorizationPrincipal,
  ): Promise<Booking> {
    const booking = await this.bookings.findOneBy({ id: bookingId });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== actorId && booking.providerId !== actorId) {
      throw new ForbiddenException('You are not a participant of this booking');
    }
    if (principal) {
      assertOwnedByParty(principal, booking.customerId, booking.providerId);
    }
    return booking;
  }

  /**
   * The wire shape. `objectKey` is intentionally absent — a storage key in an
   * API response is one leaked URL away from being public.
   */
  present(photo: JobProofPhoto) {
    return {
      id: photo.id,
      bookingId: photo.bookingId,
      stage: photo.stage,
      contentType: photo.contentType,
      sizeBytes: photo.sizeBytes,
      createdAt: photo.createdAt,
    };
  }
}
