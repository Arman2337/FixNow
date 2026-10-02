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
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import {
  COMPLAINT_STATUSES_REQUIRING_NOTES,
  VALID_COMPLAINT_TRANSITIONS,
  isTerminalComplaintStatus,
  isValidComplaintTransition,
} from '../../../../shared/complaint-lifecycle.types';
import { TrustService } from '../../trust/trust.service';
import { Booking } from '../../bookings/domain/booking.entity';
import { TrustedEvidenceUrl } from './trusted-evidence-url';
import type { ConfigService } from '@nestjs/config';

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

  const mockBookingRepository = {
    findOne: jest.fn(),
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
          provide: getRepositoryToken(Booking),
          useValue: mockBookingRepository,
        },
        {
          provide: TrustedEvidenceUrl,
          useValue: new TrustedEvidenceUrl({
            get: (key: string) =>
              key === 'EVIDENCE_ALLOWED_ORIGINS'
                ? 'https://cdn.fixnow.test'
                : undefined,
          } as unknown as ConfigService<never, true>),
        },
        {
          provide: TrustService,
          useValue: { evaluateComplaintSignal: mockEvaluateComplaintSignal },
        },
      ],
    }).compile();

    service = module.get<ComplaintsService>(ComplaintsService);
    jest.clearAllMocks();
    // Default: the caller is the customer on the booking they complain about.
    mockBookingRepository.findOne.mockResolvedValue({
      id: 'booking-1',
      customerId: 'user-1',
      providerId: 'provider-1',
    });
  });

  it('should create a complaint and save evidence', async () => {
    const submitterId = 'user-1';
    const dto = {
      bookingId: 'booking-1',
      targetRole: ComplaintTargetRole.PROVIDER,
      targetId: 'provider-1',
      category: 'Unprofessional Behavior',
      description: 'The provider was rude.',
      evidence: [
        { fileUrl: 'https://cdn.fixnow.test/img.png', fileType: 'image/png' },
      ],
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

  // SEC-002 regression: bookingId/targetId used to be written straight from
  // the request body, so one account could replay this endpoint to manufacture
  // a trust-and-safety signal against an arbitrary user.
  describe('complaint target validation (SEC-002)', () => {
    const baseDto = {
      targetRole: ComplaintTargetRole.PROVIDER,
      category: 'Unprofessional Behavior',
      description: 'The provider was rude.',
    };

    it('refuses a complaint with no bookingId, so no target can be named freely', async () => {
      await expect(
        service.createComplaint('user-1', { ...baseDto, targetId: 'victim' }),
      ).rejects.toThrow(ForbiddenException);

      expect(mockComplaintRepository.save).not.toHaveBeenCalled();
      expect(mockEvaluateComplaintSignal).not.toHaveBeenCalled();
    });

    it('refuses a booking the caller is not a party to', async () => {
      mockBookingRepository.findOne.mockResolvedValue({
        id: 'booking-1',
        customerId: 'someone-else',
        providerId: 'provider-1',
      });

      await expect(
        service.createComplaint('attacker', {
          ...baseDto,
          bookingId: 'booking-1',
          targetId: 'provider-1',
        }),
      ).rejects.toThrow(NotFoundException);

      expect(mockComplaintRepository.save).not.toHaveBeenCalled();
      expect(mockEvaluateComplaintSignal).not.toHaveBeenCalled();
    });

    it('refuses a target that is not the counterparty on the booking', async () => {
      await expect(
        service.createComplaint('user-1', {
          ...baseDto,
          bookingId: 'booking-1',
          targetId: 'unrelated-victim',
        }),
      ).rejects.toThrow(NotFoundException);

      expect(mockComplaintRepository.save).not.toHaveBeenCalled();
      expect(mockEvaluateComplaintSignal).not.toHaveBeenCalled();
    });

    it('refuses a provider complaint raised by the provider themselves', async () => {
      await expect(
        service.createComplaint('provider-1', {
          ...baseDto,
          bookingId: 'booking-1',
          targetId: 'provider-1',
        }),
      ).rejects.toThrow(NotFoundException);

      expect(mockEvaluateComplaintSignal).not.toHaveBeenCalled();
    });
  });

  // A customer-controlled link rendered in the support-agent console is an
  // outbound phishing primitive: the agent opening the case is the target.
  describe('evidence links (SEC-003)', () => {
    const baseEvidenceDto = {
      bookingId: 'booking-1',
      targetRole: ComplaintTargetRole.PROVIDER,
      targetId: 'provider-1',
      category: 'Unprofessional Behavior',
      description: 'See attached.',
    };

    it('refuses evidence on a host we do not control', async () => {
      await expect(
        service.createComplaint('user-1', {
          ...baseEvidenceDto,
          evidence: [
            {
              fileUrl: 'https://fixnow-evidence-verify.example/login',
              fileType: 'image/png',
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
      expect(mockEvidenceRepository.save).not.toHaveBeenCalled();
    });

    it('refuses a plain-http evidence link', async () => {
      await expect(
        service.createComplaint('user-1', {
          ...baseEvidenceDto,
          evidence: [
            { fileUrl: 'http://cdn.fixnow.test/a.png', fileType: 'image/png' },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
      expect(mockEvidenceRepository.save).not.toHaveBeenCalled();
    });

    it('writes nothing at all when an evidence link is refused', async () => {
      await expect(
        service.createComplaint('user-1', {
          ...baseEvidenceDto,
          evidence: [
            { fileUrl: 'https://evil.example/a.png', fileType: 'image/png' },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
      // Validation happens before the first write, so there is no orphaned
      // complaint row left behind.
      expect(mockComplaintRepository.save).not.toHaveBeenCalled();
    });
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
      fileUrl: 'https://cdn.fixnow.test/proof.png',
      fileType: 'image/png',
    });
    mockEvidenceRepository.save.mockResolvedValue({
      id: 'evidence-1',
      complaintId: complaint.id,
    });

    await service.addEvidence('comp-1', 'user-1', {
      fileUrl: 'https://cdn.fixnow.test/proof.png',
      fileType: 'image/png',
      description: 'Meter reading',
    });

    expect(mockEvidenceRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        complaintId: 'comp-1',
        uploadedBy: 'user-1',
        fileUrl: 'https://cdn.fixnow.test/proof.png',
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

  /**
   * SEC-011. The complaint status transition table.
   *
   * These are the assertions the audit said would have caught the gap on day one:
   * the declared table and the enforced table must agree, a terminal state must
   * be terminal, and every non-terminal state must be able to reach a terminal
   * one. They are pure functions of the transition table, which is why they cost
   * almost nothing and why they belong beside the service that enforces it.
   */
  describe('complaint lifecycle transitions (SEC-011)', () => {
    const ALL_STATUSES = Object.values(ComplaintStatus);
    const TERMINAL = ALL_STATUSES.filter((s) => isTerminalComplaintStatus(s));

    it('declares every status in the enum', () => {
      expect(Object.keys(VALID_COMPLAINT_TRANSITIONS).sort()).toEqual(
        [...ALL_STATUSES].sort(),
      );
    });

    it('treats CLOSED as the only terminal state', () => {
      expect(TERMINAL).toEqual([ComplaintStatus.CLOSED]);
    });

    it('refuses to move a terminal complaint to anything', () => {
      for (const target of ALL_STATUSES) {
        expect(isValidComplaintTransition(ComplaintStatus.CLOSED, target)).toBe(
          false,
        );
      }
    });

    it('refuses to move a complaint to itself', () => {
      for (const status of ALL_STATUSES) {
        expect(isValidComplaintTransition(status, status)).toBe(false);
      }
    });

    it('never reopens a resolved complaint', () => {
      expect(
        isValidComplaintTransition(
          ComplaintStatus.RESOLVED,
          ComplaintStatus.OPEN,
        ),
      ).toBe(false);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.RESOLVED,
          ComplaintStatus.IN_REVIEW,
        ),
      ).toBe(false);
    });

    it('lets every non-terminal status reach a terminal one', () => {
      for (const from of ALL_STATUSES.filter(
        (s) => !isTerminalComplaintStatus(s),
      )) {
        expect(VALID_COMPLAINT_TRANSITIONS[from].length).toBeGreaterThan(0);
        const reachesTerminal = VALID_COMPLAINT_TRANSITIONS[from].some((to) =>
          isTerminalComplaintStatus(to),
        );
        expect(reachesTerminal).toBe(true);
      }
    });

    it('requires notes for the two outcomes a customer will be told about', () => {
      expect(
        COMPLAINT_STATUSES_REQUIRING_NOTES.has(ComplaintStatus.RESOLVED),
      ).toBe(true);
      expect(
        COMPLAINT_STATUSES_REQUIRING_NOTES.has(ComplaintStatus.CLOSED),
      ).toBe(true);
    });
  });

  describe('updateComplaintStatus enforces the table (SEC-011)', () => {
    it('rejects an illegal transition and writes no audit row', async () => {
      mockComplaintRepository.findOne.mockResolvedValue({
        id: 'comp-1',
        status: ComplaintStatus.CLOSED,
      });

      await expect(
        service.updateComplaintStatus(
          'comp-1',
          ComplaintStatus.OPEN,
          'admin-1',
          'reopening for no stated reason',
        ),
      ).rejects.toBeInstanceOf(ConflictException);

      expect(mockComplaintRepository.save).not.toHaveBeenCalled();
      expect(mockAuditRepository.save).not.toHaveBeenCalled();
    });

    it('rejects replaying the current status', async () => {
      mockComplaintRepository.findOne.mockResolvedValue({
        id: 'comp-1',
        status: ComplaintStatus.IN_REVIEW,
      });

      await expect(
        service.updateComplaintStatus(
          'comp-1',
          ComplaintStatus.IN_REVIEW,
          'admin-1',
        ),
      ).rejects.toBeInstanceOf(ConflictException);

      expect(mockAuditRepository.save).not.toHaveBeenCalled();
    });

    it('requires resolution notes when resolving', async () => {
      mockComplaintRepository.findOne.mockResolvedValue({
        id: 'comp-1',
        status: ComplaintStatus.IN_REVIEW,
      });

      await expect(
        service.updateComplaintStatus(
          'comp-1',
          ComplaintStatus.RESOLVED,
          'admin-1',
        ),
      ).rejects.toBeInstanceOf(BadRequestException);

      expect(mockAuditRepository.save).not.toHaveBeenCalled();
    });

    it('accepts a legal transition and audits the previous status', async () => {
      mockComplaintRepository.findOne.mockResolvedValue({
        id: 'comp-1',
        status: ComplaintStatus.OPEN,
      });
      mockComplaintRepository.save.mockImplementation((c) =>
        Promise.resolve(c),
      );
      mockAuditRepository.save.mockResolvedValue({ id: 'audit-1' });

      await service.updateComplaintStatus(
        'comp-1',
        ComplaintStatus.IN_REVIEW,
        'admin-1',
      );

      expect(mockAuditRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          complaintId: 'comp-1',
          previousStatus: ComplaintStatus.OPEN,
          newStatus: ComplaintStatus.IN_REVIEW,
        }),
      );
    });
  });
});
