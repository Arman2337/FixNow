import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ComplaintsService } from './complaints.service';
import { CreateComplaintDto, EvidenceDto } from './dto/create-complaint.dto';
import { AuthorizationGuard } from '../../common/authorization/authorization.guard';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../../common/authorization/permission-policies';

@Controller('support/complaints')
@UseGuards(AuthorizationGuard)
export class ComplaintsController {
  constructor(private readonly complaintsService: ComplaintsService) {}

  @Post()
  @RequireOwnPermission(PERMISSIONS.complaintsCreate)
  async createComplaint(
    @Req() req: AuthorizedRequest,
    @Body() dto: CreateComplaintDto,
  ) {
    const userId = req.authorizationPrincipal!.userId;
    return this.complaintsService.createComplaint(userId, dto);
  }

  @Get()
  @RequireOwnPermission(PERMISSIONS.complaintsReadSelf)
  async getComplaints(@Req() req: AuthorizedRequest) {
    const userId = req.authorizationPrincipal!.userId;
    return this.complaintsService.getComplaints(userId, false);
  }

  @Post(':id/evidence')
  @RequireOwnPermission(PERMISSIONS.complaintsCreate)
  async addEvidence(
    @Req() req: AuthorizedRequest,
    @Param('id') id: string,
    @Body() dto: EvidenceDto,
  ) {
    const userId = req.authorizationPrincipal!.userId;
    return this.complaintsService.addEvidence(id, userId, dto);
  }

  @Post(':id/callback-request')
  @RequireOwnPermission(PERMISSIONS.complaintsCreate)
  async requestCallback(
    @Req() req: AuthorizedRequest,
    @Param('id') id: string,
  ) {
    const userId = req.authorizationPrincipal!.userId;
    return this.complaintsService.requestCallback(id, userId);
  }

  @Get(':id')
  @RequireOwnPermission(PERMISSIONS.complaintsReadSelf)
  async getComplaintById(
    @Req() req: AuthorizedRequest,
    @Param('id') id: string,
  ) {
    const userId = req.authorizationPrincipal!.userId;
    return this.complaintsService.getComplaintById(id, userId, false);
  }
}
