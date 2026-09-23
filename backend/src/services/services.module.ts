import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { ServiceCategoryEntity } from './service-category.entity';
import { ServiceCategoriesController } from './service-categories.controller';
import { ServiceCategoriesService } from './service-categories.service';

import { SubServiceEntity } from './sub-service.entity';
import { SubServicesController } from './sub-services.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ServiceCategoryEntity, SubServiceEntity]), AuthModule],
  controllers: [ServiceCategoriesController, SubServicesController],
  providers: [ServiceCategoriesService],
  exports: [ServiceCategoriesService],
})
export class ServicesModule {}
