import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Complaint, ComplaintStatus } from './domain/complaint.entity';
import { ComplaintEvidence } from './domain/complaint-evidence.entity';
import { ComplaintAudit } from './domain/complaint-audit.entity';
import { CreateComplaintDto, EvidenceDto } from './dto/create-complaint.dto';
import { AppealStatus } from '../../../../shared/trust.types';
import { ComplaintTargetRole } from './domain/complaint.entity';
import { TrustService } from '../../trust/trust.service';
import { Booking } from '../../bookings/domain/booking.entity';

@Injectable()
export class ComplaintsService {
  constructor(
    @InjectRepository(Complaint)
    private readonly complaintsRepository: Repository<Complaint>,
    @InjectRepository(ComplaintEvidence)
    private readonly evidenceRepository: Repository<ComplaintEvidence>,
    @InjectRepository(ComplaintAudit)
    private readonly auditRepository: Repository<ComplaintAudit>,
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
    private readonly trust?: TrustService,
  ) {}

  /**
   * SEC-002: `bookingId` and `targetId` used to be written straight from the
   * request body. Because the trust engine counts stored complaints per target,
   * a single account could replay this endpoint to manufacture a MEDIUM
   * trust-and-safety signal against any user, and could attach an uninvolved
   * customer's booking to its own case. Both ids are now proved against the
   * caller before anything is written.
   */
  async createComplaint(
    submitterId: string,
    dto: CreateComplaintDto,
  ): Promise<Complaint> {
    await this.assertTargetIsRelatedToCaller(submitterId, dto);

    const complaint = this.complaintsRepository.create({
      submitterId,
      bookingId: dto.bookingId,
      targetRole: dto.targetRole,
      targetId: dto.targetId,
      category: dto.category,
      description: dto.description,
      status: ComplaintStatus.OPEN,
    });

    const savedComplaint = await this.complaintsRepository.save(complaint);

    // FN-060: review signal recording is best-effort; it can never fail a
    // complaint submission. The target has been proved related to the caller
    // by this point, so the signal reflects a real service interaction.
    if (dto.targetRole === ComplaintTargetRole.PROVIDER && dto.targetId) {
      try {
        await this.trust?.evaluateComplaintSignal(dto.targetId);
      } catch {
        // Signal evaluation failures are non-fatal by design.
      }
    }

    if (dto.evidence && dto.evidence.length > 0) {
      const evidenceEntities = dto.evidence.map((ev) =>
        this.evidenceRepository.create({
          complaintId: savedComplaint.id,
          uploadedBy: submitterId,
          fileUrl: ev.fileUrl,
          fileType: ev.fileType,
          description: ev.description,
        }),
      );
      await this.evidenceRepository.save(evidenceEntities);
    }

    return this.getComplaintById(savedComplaint.id, submitterId);
  }

  /**
   * A complaint may only be raised about a booking the caller is a party to,
   * and the complained-about party must be the counterparty on that booking.
   *
   * Rejections are deliberately indistinguishable from "not found" so this
   * cannot be used to probe whether an arbitrary booking or user id exists.
   */
  private async assertTargetIsRelatedToCaller(
    submitterId: string,
    dto: CreateComplaintDto,
  ): Promise<void> {
    if (!dto.bookingId) {
      // Without a booking there is no relationship to prove, so there is
      // nothing to complain about. Previously this path let a caller name any
      // `targetId` at all.
      throw new ForbiddenException(
        'A bookingId is required so the complaint can be validated against your booking',
      );
    }

    const booking = await this.bookingRepository.findOne({
      where: { id: dto.bookingId },
    });

    // A booking the caller is not a party to, or that does not exist, is
    // reported identically so this cannot probe for valid ids.
    const isCustomer = booking?.customerId === submitterId;
    const isProvider = booking?.providerId === submitterId;
    if (!booking || (!isCustomer && !isProvider)) {
      throw new NotFoundException('Booking not found for this complaint');
    }

    if (dto.targetId) {
      // The target must be the counterparty on the booking. A caller can never
      // be the target of their own complaint, and can never aim one at a
      // third party.
      const counterparty = isCustomer ? booking.providerId : booking.customerId;
      if (dto.targetId !== counterparty) {
        throw new NotFoundException('Booking not found for this complaint');
      }
    }

    if (dto.targetRole === ComplaintTargetRole.PROVIDER && !isCustomer) {
      // Only the customer can raise a complaint against the provider.
      throw new NotFoundException('Booking not found for this complaint');
    }
  }

  async getComplaintById(
    id: string,
    userId: string,
    isAdmin = false,
  ): Promise<Complaint> {
    const complaint = await this.complaintsRepository.findOne({
      where: { id },
      relations: { evidence: true },
    });

    if (!complaint) {
      throw new NotFoundException(`Complaint with ID ${id} not found`);
    }

    if (
      !isAdmin &&
      complaint.submitterId !== userId &&
      complaint.targetId !== userId
    ) {
      throw new ForbiddenException('You do not have access to this complaint');
    }

    if (
      !isAdmin &&
      complaint.targetId === userId &&
      complaint.submitterId !== userId
    ) {
      // Redact submitter identity to prevent retaliation
      complaint.submitterId = 'REDACTED';
    }

    return complaint;
  }

  async addEvidence(
    id: string,
    actorId: string,
    dto: EvidenceDto,
  ): Promise<Complaint> {
    const complaint = await this.complaintsRepository.findOne({
      where: { id },
    });

    if (!complaint) {
      throw new NotFoundException(`Complaint with ID ${id} not found`);
    }

    if (complaint.targetId !== actorId && complaint.submitterId !== actorId) {
      throw new ForbiddenException(
        'Only parties involved can add evidence to this complaint',
      );
    }

    await this.evidenceRepository.save(
      this.evidenceRepository.create({
        complaintId: complaint.id,
        uploadedBy: actorId,
        fileUrl: dto.fileUrl,
        fileType: dto.fileType,
        description: dto.description,
      }),
    );

    return this.getComplaintById(id, actorId, false);
  }

  async requestCallback(id: string, actorId: string): Promise<Complaint> {
    const complaint = await this.complaintsRepository.findOne({
      where: { id },
    });

    if (!complaint) {
      throw new NotFoundException(`Complaint with ID ${id} not found`);
    }

    if (complaint.targetId !== actorId && complaint.submitterId !== actorId) {
      throw new ForbiddenException(
        'Only parties involved can request a callback for this complaint',
      );
    }

    await this.auditRepository.save(
      this.auditRepository.create({
        complaintId: complaint.id,
        actorId,
        previousStatus: complaint.status,
        newStatus: complaint.status,
        notes: 'Callback requested by case participant',
      }),
    );

    return complaint;
  }

  async getComplaints(userId: string, isAdmin = false): Promise<Complaint[]> {
    let complaints = [];
    if (isAdmin) {
      complaints = await this.complaintsRepository.find({
        order: { createdAt: 'DESC' },
      });
    } else {
      complaints = await this.complaintsRepository.find({
        where: [{ submitterId: userId }, { targetId: userId }],
        order: { createdAt: 'DESC' },
      });
    }

    if (!isAdmin) {
      complaints.forEach((complaint) => {
        if (complaint.targetId === userId && complaint.submitterId !== userId) {
          complaint.submitterId = 'REDACTED';
        }
      });
    }

    return complaints;
  }

  async updateComplaintStatus(
    id: string,
    status: ComplaintStatus,
    adminId: string,
    resolutionNotes?: string,
  ): Promise<Complaint> {
    const complaint = await this.complaintsRepository.findOne({
      where: { id },
    });

    if (!complaint) {
      throw new NotFoundException(`Complaint with ID ${id} not found`);
    }

    const previousStatus = complaint.status;
    complaint.status = status;
    complaint.assigneeId = adminId;
    if (resolutionNotes) {
      complaint.resolutionNotes = resolutionNotes;
    }

    const updatedComplaint = await this.complaintsRepository.save(complaint);

    await this.auditRepository.save(
      this.auditRepository.create({
        complaintId: updatedComplaint.id,
        actorId: adminId,
        previousStatus,
        newStatus: status,
        notes: resolutionNotes,
      }),
    );

    return updatedComplaint;
  }

  async submitAppeal(
    id: string,
    actorId: string,
    reason: string,
  ): Promise<Complaint> {
    const complaint = await this.complaintsRepository.findOne({
      where: { id },
    });
    if (!complaint) {
      throw new NotFoundException(`Complaint with ID ${id} not found`);
    }

    if (complaint.targetId !== actorId && complaint.submitterId !== actorId) {
      throw new ForbiddenException(
        'Only parties involved can appeal this complaint',
      );
    }

    complaint.appealStatus = AppealStatus.PENDING;
    complaint.appealReason = reason;
    return this.complaintsRepository.save(complaint);
  }
}
