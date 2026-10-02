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
import {
  assertNoResourceToProve,
  assertOwnedByParty,
} from '../../common/authorization/resource-ownership';

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
    const principal = req.authorizationPrincipal!;
    // SEC-002: the service proves the caller is a party to the named booking
    // and that the target is the counterparty; the complaint row then carries
    // both party columns, so assert on them.
    const complaint = await this.complaintsService.createComplaint(
      principal.userId,
      dto,
    );
    assertOwnedByParty(principal, complaint.submitterId, complaint.targetId);
    return complaint;
  }

  @Get()
  @RequireOwnPermission(PERMISSIONS.complaintsReadSelf)
  async getComplaints(@Req() req: AuthorizedRequest) {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    const complaints = await this.complaintsService.getComplaints(
      userId,
      false,
    );
    // SEC-002: a case is visible to its submitter *or* its target. Every row
    // returned must be a case the caller is a party to. An empty inbox has
    // proven nothing to leak.
    if (complaints.length === 0) assertNoResourceToProve(principal);
    for (const complaint of complaints) {
      assertOwnedByParty(principal, complaint.submitterId, complaint.targetId);
    }
    return complaints;
  }

  @Post(':id/evidence')
  @RequireOwnPermission(PERMISSIONS.complaintsCreate)
  async addEvidence(
    @Req() req: AuthorizedRequest,
    @Param('id') id: string,
    @Body() dto: EvidenceDto,
  ) {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    const complaint = await this.complaintsService.addEvidence(id, userId, dto);
    assertOwnedByParty(principal, complaint.submitterId, complaint.targetId);
    return complaint;
  }

  @Post(':id/callback-request')
  @RequireOwnPermission(PERMISSIONS.complaintsCreate)
  async requestCallback(
    @Req() req: AuthorizedRequest,
    @Param('id') id: string,
  ) {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    const complaint = await this.complaintsService.requestCallback(id, userId);
    assertOwnedByParty(principal, complaint.submitterId, complaint.targetId);
    return complaint;
  }

  @Get(':id')
  @RequireOwnPermission(PERMISSIONS.complaintsReadSelf)
  async getComplaintById(
    @Req() req: AuthorizedRequest,
    @Param('id') id: string,
  ) {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    const complaint = await this.complaintsService.getComplaintById(
      id,
      userId,
      false,
    );
    assertOwnedByParty(principal, complaint.submitterId, complaint.targetId);
    return complaint;
  }
}
