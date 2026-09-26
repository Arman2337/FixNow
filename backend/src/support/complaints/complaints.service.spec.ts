import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ComplaintsService } from './complaints.service';
import {
  Complaint,
  ComplaintStatus,
  ComplaintTargetRole,
} from './domain/complaint.entity';
import { ComplaintEvidence } from './domain/complaint-evidence.entity';
import { ComplaintAudit } from './domain/complaint-audit.entity';
import { ForbiddenException } from '@nestjs/common';
import { TrustService } from '../../trust/trust.service';

describe('ComplaintsService', () => {
  let service: ComplaintsService;

  const mockEvaluateComplaintSignal = jest.fn().mockResolvedValue(null);

  const mockComplaintRepository = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
    find: jest.fn(),
  };

  const mockEvidenceRepository = {
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockAuditRepository = {
    create: jest.fn(),
    save: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ComplaintsService,
        {
          provide: getRepositoryToken(Complaint),
          useValue: mockComplaintRepository,
        },
        {
          provide: getRepositoryToken(ComplaintEvidence),
          useValue: mockEvidenceRepository,
        },
        {
          provide: getRepositoryToken(ComplaintAudit),
          useValue: mockAuditRepository,
        },
        {
          provide: TrustService,
          useValue: { evaluateComplaintSignal: mockEvaluateComplaintSignal },
        },
      ],
    }).compile();

    service = module.get<ComplaintsService>(ComplaintsService);
    jest.clearAllMocks();
  });

  it('should create a complaint and save evidence', async () => {
    const submitterId = 'user-1';
    const dto = {
      targetRole: ComplaintTargetRole.PROVIDER,
      category: 'Unprofessional Behavior',
      description: 'The provider was rude.',
      evidence: [{ fileUrl: 'http://test.com/img.png', fileType: 'image/png' }],
    };

    mockComplaintRepository.create.mockReturnValue({
      id: 'comp-1',
      ...dto,
      submitterId,
    });
    mockComplaintRepository.save.mockResolvedValue({
      id: 'comp-1',
      ...dto,
      submitterId,
    });
    mockComplaintRepository.findOne.mockResolvedValue({
      id: 'comp-1',
      ...dto,
      submitterId,
    });

    const result = await service.createComplaint(submitterId, dto);

    expect(mockComplaintRepository.save).toHaveBeenCalled();
    expect(mockEvidenceRepository.save).toHaveBeenCalled();
    expect(result.id).toBe('comp-1');
  });

  it('should restrict access to complaint by non-submitter/target if not admin', async () => {
    mockComplaintRepository.findOne.mockResolvedValue({
      id: 'comp-1',
      submitterId: 'user-1',
      targetId: 'user-2',
    });

    await expect(
      service.getComplaintById('comp-1', 'user-3', false),
    ).rejects.toThrow(ForbiddenException);
  });

  it('should allow admin access to any complaint', async () => {
    mockComplaintRepository.findOne.mockResolvedValue({
      id: 'comp-1',
      submitterId: 'user-1',
      targetId: 'user-2',
    });

    const result = await service.getComplaintById('comp-1', 'admin-1', true);
    expect(result.id).toBe('comp-1');
  });

  it('loads evidence only for an authorized complaint detail lookup', async () => {
    const evidence = {
      id: 'evidence-1',
      fileType: 'image/png',
      fileUrl: 'https://example.test/evidence-1',
    };
    mockComplaintRepository.findOne.mockResolvedValue({
      id: 'comp-1',
      submitterId: 'user-1',
      targetId: 'user-2',
      evidence: [evidence],
    });

    await expect(
      service.getComplaintById('comp-1', 'admin-1', true),
    ).resolves.toMatchObject({ evidence: [evidence] });
    expect(mockComplaintRepository.findOne).toHaveBeenCalledWith({
      where: { id: 'comp-1' },
      relations: { evidence: true },
    });
  });

  it('adds evidence only for a complaint participant', async () => {
    const complaint = {
      id: 'comp-1',
      submitterId: 'user-1',
      targetId: 'user-2',
      status: ComplaintStatus.OPEN,
    };
    mockComplaintRepository.findOne.mockResolvedValue(complaint);
    mockEvidenceRepository.create.mockReturnValue({
      complaintId: complaint.id,
      uploadedBy: 'user-1',
      fileUrl: 'https://example.test/proof.png',
      fileType: 'image/png',
    });
    mockEvidenceRepository.save.mockResolvedValue({
      id: 'evidence-1',
      complaintId: complaint.id,
    });

    await service.addEvidence('comp-1', 'user-1', {
      fileUrl: 'https://example.test/proof.png',
      fileType: 'image/png',
      description: 'Meter reading',
    });

    expect(mockEvidenceRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        complaintId: 'comp-1',
        uploadedBy: 'user-1',
        fileUrl: 'https://example.test/proof.png',
      }),
    );
  });

  it('records a callback request for a complaint participant', async () => {
    const complaint = {
      id: 'comp-1',
      submitterId: 'user-1',
      targetId: 'user-2',
      status: ComplaintStatus.IN_REVIEW,
    };
    mockComplaintRepository.findOne.mockResolvedValue(complaint);
    mockAuditRepository.save.mockResolvedValue({ id: 'audit-1' });

    await service.requestCallback('comp-1', 'user-2');

    expect(mockAuditRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        complaintId: 'comp-1',
        actorId: 'user-2',
        previousStatus: ComplaintStatus.IN_REVIEW,
        newStatus: ComplaintStatus.IN_REVIEW,
        notes: 'Callback requested by case participant',
      }),
    );
    expect(mockAuditRepository.save).toHaveBeenCalled();
  });
  it('should update complaint status and add resolution notes', async () => {
    mockComplaintRepository.findOne.mockResolvedValue({
      id: 'comp-1',
      status: ComplaintStatus.OPEN,
    });
    mockComplaintRepository.save.mockImplementation((c) => Promise.resolve(c));

    const result = await service.updateComplaintStatus(
      'comp-1',
      ComplaintStatus.RESOLVED,
      'admin-1',
      'Resolved the issue by talking to the provider',
    );

    expect(result.status).toBe(ComplaintStatus.RESOLVED);
    expect(result.resolutionNotes).toBe(
      'Resolved the issue by talking to the provider',
    );
    expect(result.assigneeId).toBe('admin-1');
  });
});
