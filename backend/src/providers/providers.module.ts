import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { ProviderApplicationEntity } from './provider-application.entity';
import { ProviderRegistrationController } from './provider-registration.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ProviderApplicationEntity]), AuthModule],
  controllers: [ProviderRegistrationController],
})
export class ProvidersModule {}
