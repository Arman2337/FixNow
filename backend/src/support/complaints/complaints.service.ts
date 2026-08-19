import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Complaint, ComplaintStatus } from './domain/complaint.entity';
import { ComplaintEvidence } from './domain/complaint-evidence.entity';
import { CreateComplaintDto } from './dto/create-complaint.dto';

@Injectable()
export class ComplaintsService {
  constructor(
    @InjectRepository(Complaint)
    private readonly complaintsRepository: Repository<Complaint>,
    @InjectRepository(ComplaintEvidence)
    private readonly evidenceRepository: Repository<ComplaintEvidence>,
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

    return complaint;
  }

  async getComplaints(userId: string, isAdmin = false): Promise<Complaint[]> {
    if (isAdmin) {
      return this.complaintsRepository.find({
        order: { createdAt: 'DESC' },
      });
    }

    return this.complaintsRepository.find({
      where: [{ submitterId: userId }, { targetId: userId }],
      order: { createdAt: 'DESC' },
    });
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

    complaint.status = status;
    complaint.assigneeId = adminId;
    if (resolutionNotes) {
      complaint.resolutionNotes = resolutionNotes;
    }

    return this.complaintsRepository.save(complaint);
  }
}
