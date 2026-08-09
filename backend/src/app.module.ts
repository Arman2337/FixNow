import { Module } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AppConfigModule } from './config/app-config.module';
import { AppLoggerModule } from './logging/logger.module';
import { DatabaseModule } from './database/database.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { RedisCacheModule } from './cache/cache.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [AppConfigModule, AppLoggerModule, DatabaseModule, RedisCacheModule, HealthModule],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
  ],
})
export class AppModule {}
