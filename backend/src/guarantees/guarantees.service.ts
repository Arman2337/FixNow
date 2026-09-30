import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { createHash } from 'crypto';
import {
  GuaranteeClaim,
  GuaranteeClaimStatus,
} from './domain/guarantee-claim.entity';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { BookingsService } from '../bookings/bookings.service';
import { MatchingService } from '../matching/matching.service';
import { CreateGuaranteeClaimDto } from './dto/create-guarantee-claim.dto';
import { UpdateGuaranteeClaimDto } from './dto/update-guarantee-claim.dto';

@Injectable()
export class GuaranteesService {
  constructor(
    @InjectRepository(GuaranteeClaim)
    private readonly claimsRepository: Repository<GuaranteeClaim>,
    @InjectRepository(Booking)
    private readonly bookingsRepository: Repository<Booking>,
    private readonly bookingsService: BookingsService,
    private readonly matchingService: MatchingService,
  ) {}

  async createClaim(
    customerId: string,
    createDto: CreateGuaranteeClaimDto,
  ): Promise<GuaranteeClaim> {
    const booking = await this.bookingsRepository.findOne({
      where: { id: createDto.bookingId, customerId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException(
        'Guarantee claim can only be submitted for completed bookings',
      );
    }

    if (!booking.completedAt) {
      throw new BadRequestException('Booking completion date is missing');
    }

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    if (booking.completedAt < thirtyDaysAgo) {
      throw new BadRequestException(
        'Guarantee claim period (30 days) has expired',
      );
    }

    const existingClaim = await this.claimsRepository.findOne({
      where: { bookingId: booking.id, customerId },
    });

    if (existingClaim) {
      throw new BadRequestException(
        'A guarantee claim already exists for this booking',
      );
    }

    const claim = this.claimsRepository.create({
      bookingId: booking.id,
      customerId,
      originalProviderId: booking.providerId,
      description: createDto.description,
      evidenceUrls: createDto.evidenceUrls,
      status: GuaranteeClaimStatus.PENDING,
    });

    return this.claimsRepository.save(claim);
  }

  async findAll(status?: GuaranteeClaimStatus): Promise<GuaranteeClaim[]> {
    const query = this.claimsRepository.createQueryBuilder('claim');

    if (status) {
      query.where('claim.status = :status', { status });
    }

    query.orderBy('claim.createdAt', 'DESC');

    return query.getMany();
  }

  async findOne(id: string): Promise<GuaranteeClaim> {
    const claim = await this.claimsRepository.findOne({ where: { id } });
    if (!claim) {
      throw new NotFoundException('Guarantee claim not found');
    }
    return claim;
  }

  async updateStatus(
    id: string,
    updateDto: UpdateGuaranteeClaimDto,
  ): Promise<GuaranteeClaim> {
    const claim = await this.findOne(id);

    if (updateDto.status) {
      claim.status = updateDto.status;
    }

    if (updateDto.adminNotes !== undefined) {
      claim.adminNotes = updateDto.adminNotes;
    }

    return this.claimsRepository.save(claim);
  }

  /**
   * BUG-011 + SEC-007.
   *
   * This used to INSERT the re-service booking straight into ASSIGNED:
   *
   *   const newBooking = this.bookingsRepository.create({
   *   ...
   *   status: BookingStatus.ASSIGNED,
   *   ...
   *   });
   *   await this.bookingsRepository.save(newBooking);
   *
   * That skipped the state machine, the version CAS and the audit log, so a
   * live job existed that `booking_events` knows nothing about - and the admin
   * booking detail reads `booking_events`, so it was invisible to exactly the
   * people who investigate it. `providerId` came from the request body
   * unvalidated, so any account could be attached to real work. And with no
   * `total_amount_minor`, `payments.service.ts` treated the remedy as
   * unpayable, so the customer could not be charged for it.
   *
   * The booking is now created through `BookingsService.createAssignedBooking`,
   * which runs INSERT + REQUESTED->ASSIGNED through the state machine in one
   * transaction with a full audit trail and catalogue-derived pricing.
   */
  async createReServiceBooking(
    id: string,
    assignedProviderId: string,
    actorUserId: string,
  ): Promise<Booking> {
    const claim = await this.findOne(id);
    if (claim.status !== GuaranteeClaimStatus.APPROVED) {
      throw new BadRequestException(
        'Claim must be approved to schedule re-service',
      );
    }
    if (claim.reServiceBookingId) {
      throw new BadRequestException(
        'A re-service booking has already been scheduled',
      );
    }

    const originalBooking = await this.bookingsRepository.findOne({
      where: { id: claim.bookingId },
    });

    if (!originalBooking)
      throw new NotFoundException('Original booking not found');

    if (
      originalBooking.locationLat === null ||
      originalBooking.locationLng === null
    ) {
      throw new BadRequestException(
        'Original booking has no location to re-service at',
      );
    }

    const qualified = await this.matchingService.isProviderQualifiedForCategory(
      assignedProviderId,
      originalBooking.serviceCategoryId,
    );
    if (!qualified) {
      throw new BadRequestException(
        'Selected provider is not an active, verified provider for this service',
      );
    }

    const idempotencyKey = `guarantee-${claim.id}`;
    const booking = await this.bookingsService.createAssignedBooking({
      customerId: claim.customerId,
      providerId: assignedProviderId,
      serviceCategoryId: originalBooking.serviceCategoryId,
      description: `[RE-SERVICE] Guarantee Claim: ${claim.description}`,
      locationLat: Number(originalBooking.locationLat),
      locationLng: Number(originalBooking.locationLng),
      // The original booking's own server-resolved snapshot, carried forward.
      // The remedy is the work that was denied, at the price that was quoted.
      items: originalBooking.items ?? null,
      idempotencyKey,
      // char(64), as every other booking writes it.
      requestFingerprint: createHash('sha256')
        .update(`${claim.id}:${originalBooking.id}`)
        .digest('hex'),
      actorUserId,
      reason: `Guarantee re-service for claim ${claim.id}`,
      isGuaranteeClaim: true,
      parentBookingId: originalBooking.id,
    });

    // Conditional so a double submit cannot overwrite the first booking's id.
    // `createAssignedBooking` is idempotent on the same key, so a retry after a
    // partial failure reattaches to this booking instead of creating a second.
    const claimed = await this.claimsRepository
      .createQueryBuilder()
      .update(GuaranteeClaim)
      .set({
        status: GuaranteeClaimStatus.COMPLETED,
        assignedProviderId,
        reServiceBookingId: booking.id,
      })
      .where('id = :id AND re_service_booking_id IS NULL', { id: claim.id })
      .execute();

    if (claimed.affected !== 1) {
      const current = await this.findOne(id);
      throw new ConflictException(
        `A re-service booking (${current.reServiceBookingId}) was already scheduled for this claim`,
      );
    }

    return booking;
  }
}
