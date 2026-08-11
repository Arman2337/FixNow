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
} from '@nestjs/common';
import {
  Public,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import {
  CreateServiceCategoryDto,
  ServiceCategoryQueryDto,
  ServiceCategoryResponseDto,
  UpdateServiceCategoryDto,
} from './service-categories.dto';
import { ServiceCategoriesService } from './service-categories.service';

@Controller('service-categories')
export class ServiceCategoriesController {
  constructor(
    private readonly serviceCategoriesService: ServiceCategoriesService,
  ) {}

  @Public()
  @Get()
  findAll(
    @Query() query: ServiceCategoryQueryDto,
  ): Promise<ServiceCategoryResponseDto[]> {
    return this.serviceCategoriesService.findAll(query);
  }

  @Public()
  @Get('active')
  getActiveCategories(): Promise<ServiceCategoryResponseDto[]> {
    return this.serviceCategoriesService.getActiveCategories();
  }

  @Public()
  @Get('emergency')
  getEmergencyCategories(): Promise<ServiceCategoryResponseDto[]> {
    return this.serviceCategoriesService.getEmergencyCategories();
  }

  @Public()
  @Get(':id')
  findById(@Param('id') id: string): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.findById(id);
  }

  @Public()
  @Get('slug/:slug')
  findBySlug(@Param('slug') slug: string): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.findBySlug(slug);
  }

  @Post()
  @RequirePermission('admin.services.create')
  create(
    @Body() createDto: CreateServiceCategoryDto,
  ): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.create(createDto);
  }

  @Put(':id')
  @RequirePermission('admin.services.update')
  update(
    @Param('id') id: string,
    @Body() updateDto: UpdateServiceCategoryDto,
  ): Promise<ServiceCategoryResponseDto> {
    return this.serviceCategoriesService.update(id, updateDto);
  }

  @Delete(':id')
  @RequirePermission('admin.services.delete')
  @HttpCode(HttpStatus.NO_CONTENT)
  delete(@Param('id') id: string): Promise<void> {
    return this.serviceCategoriesService.delete(id);
  }
}
