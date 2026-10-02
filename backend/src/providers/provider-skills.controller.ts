import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
  Request,
} from '@nestjs/common';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  Public,
  RequireOwnPermission,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import {
  assertNoResourceToProve,
  assertOwnedCollection,
  assertOwnedResource,
} from '../common/authorization/resource-ownership';
import {
  CreateProviderSkillDto,
  ProviderSkillQueryDto,
  ProviderSkillResponseDto,
  ProviderSkillsCountDto,
  UpdateProviderSkillDto,
  VerifyProviderSkillDto,
} from './provider-skills.dto';
import { ProviderSkillsService } from './provider-skills.service';

@Controller('provider-skills')
export class ProviderSkillsController {
  constructor(private readonly providerSkillsService: ProviderSkillsService) {}

  @Get('me')
  @RequireOwnPermission('provider.skills.read')
  async getMySkills(
    @Request() request: AuthorizedRequest,
    @Query() query: ProviderSkillQueryDto,
  ): Promise<ProviderSkillResponseDto[]> {
    const principal = request.authorizationPrincipal!;
    const skills = await this.providerSkillsService.findByUserId(
      principal.userId,
      query,
    );
    // SEC-002: the ownership guarantee is the `skill.userId = :userId`
    // predicate in the query builder; check it against the rows actually read.
    assertOwnedCollection(principal, skills, 'userId');
    return skills;
  }

  @Get('me/count')
  @RequireOwnPermission('provider.skills.read')
  getMySkillsCount(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderSkillsCountDto> {
    // Two aggregate counts over the caller's own rows: no row is returned, so
    // there is no resource to prove ownership over.
    assertNoResourceToProve(request.authorizationPrincipal);
    return this.providerSkillsService.getProviderSkillsCount(
      request.authorizationPrincipal!.userId,
    );
  }

  /**
   * Reading another provider's skills.
   *
   * SEC-002: this is `@RequirePermission('provider.skills.read.any')`, whose
   * policy has no `relationship` clause — so it raises no deferred obligation
   * and correctly needs no discharge call. The policy restricts it to
   * `provider_reviewer`, `service_catalog_manager`, `operations_administrator`
   * and `auditor`; that role list is the whole access control here and is left
   * exactly as it is.
   */
  @Get('user/:userId')
  @RequirePermission('provider.skills.read.any')
  getProviderSkills(
    @Param('userId') userId: string,
    @Query() query: ProviderSkillQueryDto,
  ): Promise<ProviderSkillResponseDto[]> {
    return this.providerSkillsService.findByUserId(userId, query);
  }

  @Public()
  @Get('category/:serviceCategoryId')
  getVerifiedSkillsByCategory(
    @Param('serviceCategoryId') serviceCategoryId: string,
  ): Promise<ProviderSkillResponseDto[]> {
    return this.providerSkillsService.findVerifiedSkillsByCategory(
      serviceCategoryId,
    );
  }

  @Get(':id')
  @RequireOwnPermission('provider.skills.read')
  async findById(
    @Param('id') id: string,
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderSkillResponseDto> {
    const principal = request.authorizationPrincipal!;
    // Scoped to the caller's own skills: this route is self-scoped, so a
    // foreign id must not resolve (SEC-002).
    const skill = await this.providerSkillsService.findOwnedById(
      id,
      principal.userId,
    );
    assertOwnedResource(principal, skill.userId, 'providerSkill.userId');
    return skill;
  }

  @Post()
  @RequireOwnPermission('provider.skills.create')
  async create(
    @Request() request: AuthorizedRequest,
    @Body() createDto: CreateProviderSkillDto,
  ): Promise<ProviderSkillResponseDto> {
    const principal = request.authorizationPrincipal!;
    const skill = await this.providerSkillsService.create(
      principal.userId,
      createDto,
    );
    assertOwnedResource(principal, skill.userId, 'providerSkill.userId');
    return skill;
  }

  @Put(':id')
  @RequireOwnPermission('provider.skills.update')
  async update(
    @Param('id') id: string,
    @Request() request: AuthorizedRequest,
    @Body() updateDto: UpdateProviderSkillDto,
  ): Promise<ProviderSkillResponseDto> {
    const principal = request.authorizationPrincipal!;
    // `update` refuses a foreign skill before writing, and the row it returns
    // is the persisted one — so this proves ownership of what was changed.
    const skill = await this.providerSkillsService.update(
      id,
      principal.userId,
      updateDto,
      false,
    );
    assertOwnedResource(principal, skill.userId, 'providerSkill.userId');
    return skill;
  }

  /**
   * Admin skill verification.
   *
   * SEC-002: `@RequirePermission('admin.skills.verify')` has no `relationship`
   * clause in its policy, so no ownership obligation is deferred and none has
   * to be discharged. The reviewer role list is the access control.
   */
  @Put(':id/verify')
  @RequirePermission('admin.skills.verify')
  verifySkill(
    @Param('id') id: string,
    @Body() verifyDto: VerifyProviderSkillDto,
  ): Promise<ProviderSkillResponseDto> {
    return this.providerSkillsService.verifySkill(
      id,
      verifyDto.isVerified,
      verifyDto.verificationNotes,
    );
  }

  @Delete(':id')
  @RequireOwnPermission('provider.skills.delete')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @Param('id') id: string,
    @Request() request: AuthorizedRequest,
  ): Promise<void> {
    await this.providerSkillsService.delete(
      id,
      request.authorizationPrincipal!.userId,
      false,
      request.authorizationPrincipal,
    );
  }
}
