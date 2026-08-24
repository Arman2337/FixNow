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
    await controller.createComplaint(req, dto);
    expect(mockComplaintsService.createComplaint).toHaveBeenCalledWith(
      'user-1',
      dto,
    );
  });

  it("lists only the caller's cases through the self-service endpoint", async () => {
    const req1 = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    } as unknown as AuthorizedRequest;
    await controller.getComplaints(req1);
    expect(mockComplaintsService.getComplaints).toHaveBeenCalledWith(
      'user-1',
      false,
    );

    // Administrative case access is intentionally provided by the separate
    // management API; this self-service endpoint never broadens scope from a
    // role supplied by a request object.
  });
});
