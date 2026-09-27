import {
  Controller,
  Post,
  Get,
  Patch,
  Param,
  Body,
  UseGuards,
  Query,
  Req,
} from '@nestjs/common';
import { GuaranteesService } from './guarantees.service';
import { CreateGuaranteeClaimDto } from './dto/create-guarantee-claim.dto';
import { UpdateGuaranteeClaimDto } from './dto/update-guarantee-claim.dto';
import { AuthorizationGuard } from '../common/authorization/authorization.guard';
import {
  RequireOwnPermission,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { GuaranteeClaimStatus } from './domain/guarantee-claim.entity';

@Controller('guarantees/claims')
@UseGuards(AuthorizationGuard)
export class GuaranteesController {
  constructor(private readonly guaranteesService: GuaranteesService) {}

  @RequireOwnPermission(PERMISSIONS.guaranteeClaimCreateSelf)
  @Post()
  createClaim(
    @Req() req: AuthorizedRequest,
    @Body() createDto: CreateGuaranteeClaimDto,
  ) {
    const userId = req.authorizationPrincipal!.userId;
    return this.guaranteesService.createClaim(userId, createDto);
  }

  @RequirePermission(PERMISSIONS.adminGuaranteesRead)
  @Get()
  findAll(@Query('status') status?: GuaranteeClaimStatus) {
    return this.guaranteesService.findAll(status);
  }

  @RequirePermission(PERMISSIONS.adminGuaranteesRead)
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.guaranteesService.findOne(id);
  }

  @RequirePermission(PERMISSIONS.adminGuaranteesUpdate)
  @Patch(':id/status')
  updateStatus(
    @Param('id') id: string,
    @Body() updateDto: UpdateGuaranteeClaimDto,
  ) {
    return this.guaranteesService.updateStatus(id, updateDto);
  }

  @RequirePermission(PERMISSIONS.adminGuaranteesUpdate)
  @Post(':id/re-service')
  createReServiceBooking(
    @Param('id') id: string,
    @Body('providerId') providerId: string,
  ) {
    return this.guaranteesService.createReServiceBooking(id, providerId);
  }
}
