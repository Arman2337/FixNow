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
import { ServiceCategoriesService } from './service-categories.service';
import {
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  ServiceCategoryQueryDto,
  ServiceCategoryResponseDto,
} from './service-categories.dto';

@ApiTags('Service Categories')
@Controller('v1/service-categories')
export class ServiceCategoriesController {
  constructor(
    private readonly serviceCategoriesService: ServiceCategoriesService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Get all service categories' })
  @ApiResponse({
    status: 200,
    description: 'List of service categories',
    type: [ServiceCategoryResponseDto],
  })
  async findAll(
    @Query() query: ServiceCategoryQueryDto,
  ): Promise<ServiceCategoryResponseDto[]> {
    return this.serviceCategoriesService.findAll(query);
  }

  @Get('active')
  @ApiOperation({ summary: 'Get active service categories' })
  @ApiResponse({
    status: 200,
    description: 'List of active service categories',
    type: [ServiceCategoryResponseDto],
  })
  async getActiveCategories(): Promise<ServiceCategoryResponseDto[]> {
    return this.serviceCategoriesService.getActiveCategories();
  }

  @Get('emergency')
  @ApiOperation({ summary: 'Get emergency service categories' })
  @ApiResponse({
    status: 200,
    description: 'List of emergency service categories',
    type: [ServiceCategoryResponseDto],
  })
  async getEmergencyCategories(): Promise<ServiceCategoryResponseDto[]> {
    return this.serviceCategoriesService.getEmergencyCategories();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get service category by ID' })
  @ApiParam({ name: 'id', description: 'Service category ID' })
  @ApiResponse({
    status: 200,
    description: 'Service category found',
    type: ServiceCategoryResponseDto,
  })
  @ApiResponse({ status: 404, description: 'Service category not found' })
  async findById(@Param('id') id: string): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.findById(id);
  }

  @Get('slug/:slug')
  @ApiOperation({ summary: 'Get service category by slug' })
  @ApiParam({ name: 'slug', description: 'Service category slug' })
  @ApiResponse({
    status: 200,
    description: 'Service category found',
    type: ServiceCategoryResponseDto,
  })
  @ApiResponse({ status: 404, description: 'Service category not found' })
  async findBySlug(
    @Param('slug') slug: string,
  ): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.findBySlug(slug);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  @RequirePermission('admin.services.create')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a new service category (Admin only)' })
  @ApiResponse({
    status: 201,
    description: 'Service category created successfully',
    type: ServiceCategoryResponseDto,
  })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Insufficient permissions' })
  async create(
    @Body() createDto: CreateServiceCategoryDto,
  ): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.create(createDto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('admin.services.update')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update service category (Admin only)' })
  @ApiParam({ name: 'id', description: 'Service category ID' })
  @ApiResponse({
    status: 200,
    description: 'Service category updated successfully',
    type: ServiceCategoryResponseDto,
  })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Service category not found' })
  async update(
    @Param('id') id: string,
    @Body() updateDto: UpdateServiceCategoryDto,
  ): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.update(id, updateDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @RequirePermission('admin.services.delete')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete service category (Admin only)' })
  @ApiParam({ name: 'id', description: 'Service category ID' })
  @ApiResponse({
    status: 204,
    description: 'Service category deleted successfully',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Service category not found' })
  async delete(@Param('id') id: string): Promise<void> {
    return this.serviceCategoriesService.delete(id);
  }
}
