import { ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ComplaintsController } from './complaints.controller';
import { ComplaintsService } from './complaints.service';
import { ComplaintTargetRole } from './domain/complaint.entity';
import { AuthorizationGuard } from '../../common/authorization/authorization.guard';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';

describe('ComplaintsController', () => {
  let controller: ComplaintsController;

  const mockComplaintsService = {
    createComplaint: jest.fn(),
    getComplaints: jest.fn(),
    getComplaintById: jest.fn(),
    updateComplaintStatus: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ComplaintsController],
      providers: [
        {
          provide: ComplaintsService,
          useValue: mockComplaintsService,
        },
      ],
    })
      .overrideGuard(AuthorizationGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<ComplaintsController>(ComplaintsController);
    jest.clearAllMocks();
  });

  it('should call createComplaint on service', async () => {
    const req = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    } as unknown as AuthorizedRequest;
    const dto = {
      targetRole: ComplaintTargetRole.PROVIDER,
      category: 'Test',
      description: 'Test description',
    };
    // SEC-002: the returned complaint must show the caller as a party.
    mockComplaintsService.createComplaint.mockResolvedValue({
      id: 'complaint-1',
      submitterId: 'user-1',
      targetId: 'provider-1',
    });
    await controller.createComplaint(req, dto);
    expect(mockComplaintsService.createComplaint).toHaveBeenCalledWith(
      'user-1',
      dto,
    );
  });

  it('refuses a complaint the caller is not a party to (SEC-002)', async () => {
    const req = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    } as unknown as AuthorizedRequest;
    mockComplaintsService.createComplaint.mockResolvedValue({
      id: 'complaint-1',
      submitterId: 'someone-else',
      targetId: 'another-provider',
    });
    await expect(
      controller.createComplaint(req, {
        targetRole: ComplaintTargetRole.PROVIDER,
        category: 'Test',
        description: 'Test description',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it("lists only the caller's cases through the self-service endpoint", async () => {
    const req1 = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    } as unknown as AuthorizedRequest;
    mockComplaintsService.getComplaints.mockResolvedValue([
      { id: 'complaint-1', submitterId: 'user-1', targetId: 'provider-1' },
      { id: 'complaint-2', submitterId: 'provider-1', targetId: 'user-1' },
    ]);
    const cases = await controller.getComplaints(req1);
    expect(mockComplaintsService.getComplaints).toHaveBeenCalledWith(
      'user-1',
      false,
    );
    expect(cases).toHaveLength(2);

    // Administrative case access is intentionally provided by the separate
    // management API; this self-service endpoint never broadens scope from a
    // role supplied by a request object.
  });

  it('rejects a case list containing a complaint the caller is not a party to', async () => {
    const req = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    } as unknown as AuthorizedRequest;
    mockComplaintsService.getComplaints.mockResolvedValue([
      { id: 'complaint-1', submitterId: 'user-1', targetId: 'provider-1' },
      { id: 'complaint-2', submitterId: 'x', targetId: 'y' },
    ]);
    await expect(controller.getComplaints(req)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('accepts an empty case list — there is nothing there to prove', async () => {
    const req = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    } as unknown as AuthorizedRequest;
    mockComplaintsService.getComplaints.mockResolvedValue([]);
    await expect(controller.getComplaints(req)).resolves.toEqual([]);
  });
});
