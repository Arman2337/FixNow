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
import { CreateComplaintDto } from './dto/create-complaint.dto';
import { AppealStatus } from '../../../../shared/trust.types';

@Injectable()
export class ComplaintsService {
  constructor(
    @InjectRepository(Complaint)
    private readonly complaintsRepository: Repository<Complaint>,
    @InjectRepository(ComplaintEvidence)
    private readonly evidenceRepository: Repository<ComplaintEvidence>,
    @InjectRepository(ComplaintAudit)
    private readonly auditRepository: Repository<ComplaintAudit>,
  ) {}

  async createComplaint(
    submitterId: string,
    dto: CreateComplaintDto,
  ): Promise<Complaint> {
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

    if (!isAdmin && complaint.targetId === userId && complaint.submitterId !== userId) {
      // Redact submitter identity to prevent retaliation
      complaint.submitterId = 'REDACTED';
    }

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
      complaints.forEach(complaint => {
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
    const complaint = await this.complaintsRepository.findOne({ where: { id } });
    if (!complaint) {
      throw new NotFoundException(`Complaint with ID ${id} not found`);
    }

    if (complaint.targetId !== actorId && complaint.submitterId !== actorId) {
      throw new ForbiddenException('Only parties involved can appeal this complaint');
    }

    complaint.appealStatus = AppealStatus.PENDING;
    complaint.appealReason = reason;
    return this.complaintsRepository.save(complaint);
  }
}
