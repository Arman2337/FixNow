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
  getMySkills(
    @Request() request: AuthorizedRequest,
    @Query() query: ProviderSkillQueryDto,
  ): Promise<ProviderSkillResponseDto[]> {
    return this.providerSkillsService.findByUserId(
      request.authorizationPrincipal!.userId,
      query,
    );
  }

  @Get('me/count')
  @RequireOwnPermission('provider.skills.read')
  getMySkillsCount(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderSkillsCountDto> {
    return this.providerSkillsService.getProviderSkillsCount(
      request.authorizationPrincipal!.userId,
    );
  }

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
  findById(@Param('id') id: string): Promise<ProviderSkillResponseDto> {
    return this.providerSkillsService.findById(id);
  }

  @Post()
  @RequireOwnPermission('provider.skills.create')
  create(
    @Request() request: AuthorizedRequest,
    @Body() createDto: CreateProviderSkillDto,
  ): Promise<ProviderSkillResponseDto> {
    return this.providerSkillsService.create(
      request.authorizationPrincipal!.userId,
      createDto,
    );
  }

  @Put(':id')
  @RequireOwnPermission('provider.skills.update')
  update(
    @Param('id') id: string,
    @Request() request: AuthorizedRequest,
    @Body() updateDto: UpdateProviderSkillDto,
  ): Promise<ProviderSkillResponseDto> {
    return this.providerSkillsService.update(
      id,
      request.authorizationPrincipal!.userId,
      updateDto,
      false,
    );
  }

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
  delete(
    @Param('id') id: string,
    @Request() request: AuthorizedRequest,
  ): Promise<void> {
    return this.providerSkillsService.delete(
      id,
      request.authorizationPrincipal!.userId,
      false,
    );
  }
}
