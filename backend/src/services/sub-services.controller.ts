import { Controller, Get, Param, Query } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SubServiceEntity } from './sub-service.entity';
import { Public } from '../common/authorization/authorization.decorators';

@Controller('sub-services')
export class SubServicesController {
  constructor(
    @InjectRepository(SubServiceEntity)
    private readonly subServiceRepo: Repository<SubServiceEntity>,
  ) {}

  @Public()
  @Get()
  async list(@Query('categoryId') categoryId?: string) {
    try {
      const query = this.subServiceRepo.createQueryBuilder('sub_service')
        .leftJoin('sub_service.category', 'category')
        .where('sub_service.isActive = :isActive', { isActive: true });

      if (categoryId) {
        const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(categoryId);
        if (isUuid) {
          query.andWhere('sub_service.categoryId = :categoryId', { categoryId });
        } else {
          const rootSlug = categoryId.replace(/[-_]services?/i, '').replace(/[-_]repair/i, '');
          query.andWhere(
            '(category.slug = :categoryId OR category.slug ILIKE :prefix)',
            { categoryId, prefix: `${rootSlug}%` },
          );
        }
      }

      return await query.getMany();
    } catch (e: any) {
      return { error: e.message, stack: e.stack };
    }
  }

  @Public()
  @Get(':id')
  async getOne(@Param('id') id: string) {
    return await this.subServiceRepo.findOneByOrFail({ id });
  }
}
