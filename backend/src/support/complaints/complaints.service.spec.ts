import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ComplaintsService } from './complaints.service';
import {
  Complaint,
  ComplaintStatus,
  ComplaintTargetRole,
} from './domain/complaint.entity';
import { ComplaintEvidence } from './domain/complaint-evidence.entity';
import { NotFoundException, ForbiddenException } from '@nestjs/common';

describe('ComplaintsService', () => {
  let service: ComplaintsService;

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
