import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { ProviderApplicationEntity } from './provider-application.entity';
import { ProviderSkillEntity } from './provider-skill.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { ProviderRegistrationController } from './provider-registration.controller';
import { ProviderSkillsController } from './provider-skills.controller';
import { ProviderSkillsService } from './provider-skills.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ProviderApplicationEntity,
      ProviderSkillEntity,
      ServiceCategoryEntity,
    ]),
    AuthModule,
  ],
  controllers: [ProviderRegistrationController, ProviderSkillsController],
  providers: [ProviderSkillsService],
  exports: [ProviderSkillsService],
})
export class ProvidersModule {}
