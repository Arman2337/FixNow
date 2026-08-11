import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../auth/types/auth.types';
import { ProviderSkillsService } from './provider-skills.service';
import {
  CreateProviderSkillDto,
  UpdateProviderSkillDto,
  ProviderSkillQueryDto,
  ProviderSkillResponseDto,
  VerifyProviderSkillDto,
  ProviderSkillsCountDto,
} from './provider-skills.dto';

@ApiTags('Provider Skills')
@Controller('v1/provider-skills')
export class ProviderSkillsController {
  constructor(private readonly providerSkillsService: ProviderSkillsService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('provider.skills.read')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get my skills' })
  @ApiResponse({
    status: 200,
    description: 'List of provider skills',
    type: [ProviderSkillResponseDto],
  })
  async getMySkills(
    @Request() req: AuthorizedRequest,
    @Query() query: ProviderSkillQueryDto,
  ): Promise<ProviderSkillResponseDto[]> {
    return this.providerSkillsService.findByUserId(req.user.userId, query);
  }

  @Get('me/count')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('provider.skills.read')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get my skills count' })
  @ApiResponse({
    status: 200,
    description: 'Skills count summary',
    type: ProviderSkillsCountDto,
  })
  async getMySkillsCount(
    @Request() req: AuthorizedRequest,
  ): Promise<ProviderSkillsCountDto> {
    return this.providerSkillsService.getProviderSkillsCount(req.user.userId);
  }

  @Get('user/:userId')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('provider.skills.read.any')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get skills for a specific provider (Admin only)' })
  @ApiParam({ name: 'userId', description: 'Provider user ID' })
  @ApiResponse({
    status: 200,
    description: 'List of provider skills',
    type: [ProviderSkillResponseDto],
  })
  async getProviderSkills(
    @Param('userId') userId: string,
    @Query() query: ProviderSkillQueryDto,
  ): Promise<ProviderSkillResponseDto[]> {
    return this.providerSkillsService.findByUserId(userId, query);
  }

  @Get('category/:serviceCategoryId')
  @ApiOperation({ summary: 'Get verified skills by service category' })
  @ApiParam({ name: 'serviceCategoryId', description: 'Service category ID' })
  @ApiResponse({
    status: 200,
    description: 'List of verified provider skills',
    type: [ProviderSkillResponseDto],
  })
  async getVerifiedSkillsByCategory(
    @Param('serviceCategoryId') serviceCategoryId: string,
  ): Promise<ProviderSkillResponseDto[]> {
    return this.providerSkillsService.findVerifiedSkillsByCategory(
      serviceCategoryId,
    );
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('provider.skills.read')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get skill by ID' })
  @ApiParam({ name: 'id', description: 'Skill ID' })
  @ApiResponse({
    status: 200,
    description: 'Provider skill found',
    type: ProviderSkillResponseDto,
  })
  @ApiResponse({ status: 404, description: 'Skill not found' })
  async findById(@Param('id') id: string): Promise<ProviderSkillResponseDto> {
    return this.providerSkillsService.findById(id);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  @RequirePermission('provider.skills.create')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Add a new skill' })
  @ApiResponse({
    status: 201,
    description: 'Skill created successfully',
    type: ProviderSkillResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid input or skill already exists',
  })
  async create(
    @Request() req: AuthorizedRequest,
    @Body() createDto: CreateProviderSkillDto,
  ): Promise<ProviderSkillResponseDto> {
    return this.providerSkillsService.create(req.user.userId, createDto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('provider.skills.update')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update skill' })
  @ApiParam({ name: 'id', description: 'Skill ID' })
  @ApiResponse({
    status: 200,
    description: 'Skill updated successfully',
    type: ProviderSkillResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: "Cannot update another provider's skill",
  })
  @ApiResponse({ status: 404, description: 'Skill not found' })
  async update(
    @Param('id') id: string,
    @Request() req: AuthorizedRequest,
    @Body() updateDto: UpdateProviderSkillDto,
  ): Promise<ProviderSkillResponseDto> {
    const isAdmin =
      req.user.permissions?.includes('admin.skills.update') ?? false;
    return this.providerSkillsService.update(
      id,
      req.user.userId,
      updateDto,
      isAdmin,
    );
  }

  @Put(':id/verify')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('admin.skills.verify')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Verify or reject a provider skill (Admin only)' })
  @ApiParam({ name: 'id', description: 'Skill ID' })
  @ApiResponse({
    status: 200,
    description: 'Skill verification updated',
    type: ProviderSkillResponseDto,
  })
  @ApiResponse({ status: 404, description: 'Skill not found' })
  async verifySkill(
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
  @UseGuards(JwtAuthGuard)
  @RequirePermission('provider.skills.delete')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete skill' })
  @ApiParam({ name: 'id', description: 'Skill ID' })
  @ApiResponse({ status: 204, description: 'Skill deleted successfully' })
  @ApiResponse({
    status: 403,
    description: "Cannot delete another provider's skill",
  })
  @ApiResponse({ status: 404, description: 'Skill not found' })
  async delete(
    @Param('id') id: string,
    @Request() req: AuthorizedRequest,
  ): Promise<void> {
    const isAdmin =
      req.user.permissions?.includes('admin.skills.delete') ?? false;
    return this.providerSkillsService.delete(id, req.user.userId, isAdmin);
  }
}
