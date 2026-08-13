import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProvidersModule } from '../providers/providers.module';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { ProviderVerificationEventEntity } from '../providers/verification/provider-verification-event.entity';
import { UserEntity } from '../users/user.entity';
import { UserRoleEntity } from '../users/user-role.entity';
import { AdminManagementController } from './admin-management.controller';
import { AdminManagementService } from './admin-management.service';
import { AdminOperationsService } from './admin-operations.service';
import { BookingsModule } from '../bookings/bookings.module';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingEvent } from '../bookings/domain/booking-event.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';

@Module({
  imports: [
    ProvidersModule,
    BookingsModule,
    TypeOrmModule.forFeature([
      UserEntity,
      UserRoleEntity,
      ProviderApplicationEntity,
      ProviderProfileEntity,
      ProviderVerificationEventEntity,
      Booking,
      BookingEvent,
      ServiceCategoryEntity,
    ]),
  ],
  controllers: [AdminManagementController],
  providers: [AdminManagementService, AdminOperationsService],
})
export class AdminModule {}
