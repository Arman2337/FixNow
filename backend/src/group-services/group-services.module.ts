import { Module } from '@nestjs/common';
import { GroupServicesController } from './group-services.controller';
import { GroupServicesService } from './group-services.service';

@Module({
  controllers: [GroupServicesController],
  providers: [GroupServicesService],
})
export class GroupServicesModule {}
