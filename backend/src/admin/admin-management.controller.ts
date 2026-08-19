import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  HttpCode,
  Query,
  Req,
  Res,
  Patch,
} from '@nestjs/common';
import type { Response } from 'express';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { ProviderDocumentService } from '../providers/documents/provider-document.service';
import { ProviderVerificationService } from '../providers/verification/provider-verification.service';
import { AdminManagementService } from './admin-management.service';
import { AdminOperationsService } from './admin-operations.service';
import {
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
} from '../services/service-categories.dto';
import { ComplaintsService } from '../support/complaints/complaints.service';
import { ComplaintStatus } from '../support/complaints/domain/complaint.entity';
import {
  AdminPageQueryDto,
  ApplicationIdParamDto,
  ClaimReviewDto,
  DocumentParamDto,
  ProviderApplicationPageQueryDto,
  ReviewDecisionDto,
  UserIdParamDto,
  BookingIdParamDto,
  BookingPageQueryDto,
  AdminCancelBookingDto,
} from './admin-management.dto';

@Controller('admin')
export class AdminManagementController {
  constructor(
    private readonly management: AdminManagementService,
    private readonly verification: ProviderVerificationService,
    private readonly documents: ProviderDocumentService,
    private readonly operations: AdminOperationsService,
    private readonly complaints: ComplaintsService,
  ) {}

  @Patch('complaints/:complaintId/status')
  @RequirePermission(PERMISSIONS.adminComplaintsUpdate)
  updateComplaintStatus(
    @Req() req: AuthorizedRequest,
    @Param('complaintId') complaintId: string,
    @Body() body: { status: ComplaintStatus; resolutionNotes?: string },
  ) {
    return this.complaints.updateComplaintStatus(
      complaintId,
      body.status,
      req.authorizationPrincipal!.userId,
      body.resolutionNotes,
    );
  }

  @Get('service-categories')
  @RequirePermission(PERMISSIONS.adminServicesRead)
  listServiceCategories() {
    return this.operations.listCategories();
  }

  @Post('service-categories')
  @RequirePermission(PERMISSIONS.adminServicesCreate)
  createServiceCategory(@Body() body: CreateServiceCategoryDto) {
    return this.operations.createCategory(body);
  }

  @Put('service-categories/:id')
  @RequirePermission(PERMISSIONS.adminServicesUpdate)
  updateServiceCategory(
    @Param('id') id: string,
    @Body() body: UpdateServiceCategoryDto,
  ) {
    return this.operations.updateCategory(id, body);
  }

  @Delete('service-categories/:id')
  @HttpCode(204)
  @RequirePermission(PERMISSIONS.adminServicesDelete)
  deleteServiceCategory(@Param('id') id: string) {
    return this.operations.deleteCategory(id);
  }

  @Get('bookings')
  @RequirePermission(PERMISSIONS.adminBookingsRead)
  listBookings(@Query() query: BookingPageQueryDto) {
    return this.operations.listBookings(query);
  }

  @Get('bookings/:bookingId')
  @RequirePermission(PERMISSIONS.adminBookingsRead)
  bookingDetail(@Param() input: BookingIdParamDto) {
    return this.operations.bookingDetail(input.bookingId);
  }

  @Post('bookings/:bookingId/cancel')
  @RequirePermission(PERMISSIONS.adminBookingsIntervene)
  cancelBooking(
    @Req() request: AuthorizedRequest,
    @Param() input: BookingIdParamDto,
    @Body() body: AdminCancelBookingDto,
  ) {
    return this.operations.cancelBooking(
      input.bookingId,
      request.authorizationPrincipal!.userId,
      body.reason,
      body.expectedVersion,
    );
  }

  @Get('users')
  @RequirePermission(PERMISSIONS.adminUsersRead)
  listUsers(@Query() query: AdminPageQueryDto) {
    return this.management.listUsers(query);
  }

  @Get('users/:userId')
  @RequirePermission(PERMISSIONS.adminUsersRead)
  userDetail(@Param() input: UserIdParamDto) {
    return this.management.userDetail(input.userId);
  }

  @Get('provider-applications')
  @RequirePermission(PERMISSIONS.adminProviderApplicationsRead)
  listApplications(@Query() query: ProviderApplicationPageQueryDto) {
    return this.management.listApplications(query);
  }

  @Get('provider-applications/:applicationId')
  @RequirePermission(PERMISSIONS.adminProviderApplicationsRead)
  applicationDetail(@Param() input: ApplicationIdParamDto) {
    return this.management.applicationDetail(input.applicationId);
  }

  @Post('provider-applications/:applicationId/claim')
  @RequirePermission(PERMISSIONS.providerVerificationReview)
  claim(
    @Req() request: AuthorizedRequest,
    @Param() input: ApplicationIdParamDto,
    @Body() body: ClaimReviewDto,
  ) {
    return this.verification.claim(
      input.applicationId,
      request.authorizationPrincipal!.userId,
      body.expectedVersion,
    );
  }

  @Post('provider-applications/:applicationId/decision')
  @RequirePermission(PERMISSIONS.providerVerificationReview)
  decide(
    @Req() request: AuthorizedRequest,
    @Param() input: ApplicationIdParamDto,
    @Body() body: ReviewDecisionDto,
  ) {
    return this.verification.decide(
      input.applicationId,
      request.authorizationPrincipal!.userId,
      body.expectedVersion,
      body.decision,
      body.reason,
    );
  }

  @Get('provider-applications/:applicationId/documents')
  @RequirePermission(PERMISSIONS.adminProviderDocumentsRead)
  async listDocuments(
    @Req() request: AuthorizedRequest,
    @Param() input: ApplicationIdParamDto,
  ) {
    return {
      documents: await this.documents.listForReview(
        request.authorizationPrincipal!.userId,
        input.applicationId,
      ),
    };
  }

  @Get('provider-applications/:applicationId/documents/:documentId')
  @RequirePermission(PERMISSIONS.adminProviderDocumentsRead)
  async readDocument(
    @Req() request: AuthorizedRequest,
    @Param() input: DocumentParamDto,
    @Res() response: Response,
  ): Promise<void> {
    const result = await this.documents.readForReview(
      request.authorizationPrincipal!.userId,
      input.applicationId,
      input.documentId,
    );
    response.setHeader('Content-Type', result.metadata.contentType);
    response.setHeader(
      'Content-Disposition',
      'attachment; filename="provider-document"',
    );
    response.setHeader('Cache-Control', 'no-store, private');
    response.send(result.content);
  }

  @Get('complaints')
  @RequirePermission(PERMISSIONS.adminComplaintsRead)
  listComplaints(@Req() req: AuthorizedRequest) {
    return this.management.listComplaints(req.authorizationPrincipal!.userId);
  }

  @Get('complaints/:complaintId')
  @RequirePermission(PERMISSIONS.adminComplaintsRead)
  complaintDetail(
    @Req() req: AuthorizedRequest,
    @Param('complaintId') complaintId: string,
  ) {
    return this.management.getComplaintDetail(
      complaintId,
      req.authorizationPrincipal!.userId,
    );
  }
}
