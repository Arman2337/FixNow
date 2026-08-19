import { Test, TestingModule } from '@nestjs/testing';
import { ComplaintsController } from './complaints.controller';
import { ComplaintsService } from './complaints.service';
import {
  ComplaintStatus,
  ComplaintTargetRole,
} from './domain/complaint.entity';
import { AuthorizationGuard } from '../../common/authorization/authorization.guard';

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
    const req: any = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    };
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

  it('should pass isAdmin flag to getComplaints based on role', async () => {
    const req1: any = {
      authorizationPrincipal: { userId: 'user-1', roles: ['customer'] },
    };
    await controller.getComplaints(req1);
    expect(mockComplaintsService.getComplaints).toHaveBeenCalledWith(
      'user-1',
      false,
    );

    const req2: any = {
      authorizationPrincipal: { userId: 'admin-1', roles: ['support_agent'] },
    };
    await controller.getComplaints(req2);
    expect(mockComplaintsService.getComplaints).toHaveBeenCalledWith(
      'admin-1',
      true,
    );
  });
});
