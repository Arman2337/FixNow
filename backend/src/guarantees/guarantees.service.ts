import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { GuaranteeClaim, GuaranteeClaimStatus } from './domain/guarantee-claim.entity';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { CreateGuaranteeClaimDto } from './dto/create-guarantee-claim.dto';
import { UpdateGuaranteeClaimDto } from './dto/update-guarantee-claim.dto';

@Injectable()
export class GuaranteesService {
  constructor(
    @InjectRepository(GuaranteeClaim)
    private readonly claimsRepository: Repository<GuaranteeClaim>,
    @InjectRepository(Booking)
    private readonly bookingsRepository: Repository<Booking>,
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
      throw new BadRequestException('Guarantee claim can only be submitted for completed bookings');
    }

    if (!booking.completedAt) {
      throw new BadRequestException('Booking completion date is missing');
    }

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    if (booking.completedAt < thirtyDaysAgo) {
      throw new BadRequestException('Guarantee claim period (30 days) has expired');
    }

    const existingClaim = await this.claimsRepository.findOne({
      where: { bookingId: booking.id, customerId },
    });

    if (existingClaim) {
      throw new BadRequestException('A guarantee claim already exists for this booking');
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

  async createReServiceBooking(id: string, assignedProviderId: string): Promise<Booking> {
    const claim = await this.findOne(id);
    if (claim.status !== GuaranteeClaimStatus.APPROVED) {
      throw new BadRequestException('Claim must be approved to schedule re-service');
    }
    if (claim.reServiceBookingId) {
      throw new BadRequestException('A re-service booking has already been scheduled');
    }

    const originalBooking = await this.bookingsRepository.findOne({
      where: { id: claim.bookingId },
    });

    if (!originalBooking) throw new NotFoundException('Original booking not found');

    const newBooking = this.bookingsRepository.create({
      customerId: claim.customerId,
      providerId: assignedProviderId,
      serviceCategoryId: originalBooking.serviceCategoryId,
      idempotencyKey: `guarantee-${claim.id}`,
      requestFingerprint: `guarantee-${claim.id}`,
      status: BookingStatus.ASSIGNED,
      description: `[RE-SERVICE] Guarantee Claim: ${claim.description}`,
      locationLat: originalBooking.locationLat,
      locationLng: originalBooking.locationLng,
      isGuaranteeClaim: true,
      parentBookingId: originalBooking.id,
      assignedAt: new Date(),
    });

    const savedBooking = await this.bookingsRepository.save(newBooking);

    claim.status = GuaranteeClaimStatus.COMPLETED;
    claim.assignedProviderId = assignedProviderId;
    claim.reServiceBookingId = savedBooking.id;
    await this.claimsRepository.save(claim);

    return savedBooking;
  }
}
