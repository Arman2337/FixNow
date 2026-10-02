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
import { ReServiceBookingDto } from './dto/re-service-booking.dto';
import { AuthorizationGuard } from '../common/authorization/authorization.guard';
import {
  RequireOwnPermission,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { assertOwnedResource } from '../common/authorization/resource-ownership';
import {
  GuaranteesPageQueryDto,
  LIST_ENDPOINT_DEFAULT_LIMIT,
} from '../common/list-pagination.dto';
import { GuaranteeClaimStatus } from './domain/guarantee-claim.entity';

@Controller('guarantees/claims')
@UseGuards(AuthorizationGuard)
export class GuaranteesController {
  constructor(private readonly guaranteesService: GuaranteesService) {}

  @RequireOwnPermission(PERMISSIONS.guaranteeClaimCreateSelf)
  @Post()
  async createClaim(
    @Req() req: AuthorizedRequest,
    @Body() createDto: CreateGuaranteeClaimDto,
  ) {
    const principal = req.authorizationPrincipal!;
    const userId = principal.userId;
    // SEC-002: the service loads the booking with `where: { id, customerId }`,
    // so a booking that is not the caller's is simply absent. The returned
    // claim still carries the owning column, so compare it rather than trust
    // that scoping.
    const claim = await this.guaranteesService.createClaim(userId, createDto);
    assertOwnedResource(
      principal,
      claim.customerId,
      'guaranteeClaim.customerId',
    );
    return claim;
  }

  /**
   * API-003: was unbounded. `guarantee_claims` is append-only, and this route
   * loaded every row to render a list.
   */
  @RequirePermission(PERMISSIONS.adminGuaranteesRead)
  @Get()
  findAll(@Query() query: GuaranteesPageQueryDto) {
    return this.guaranteesService.findAll(
      query.status as GuaranteeClaimStatus | undefined,
      query.limit ?? LIST_ENDPOINT_DEFAULT_LIMIT,
    );
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
    @Body() body: ReServiceBookingDto,
    @Req() req: AuthorizedRequest,
  ) {
    return this.guaranteesService.createReServiceBooking(
      id,
      body.providerId,
      req.authorizationPrincipal!.userId,
    );
  }
}
