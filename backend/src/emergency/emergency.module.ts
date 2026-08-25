import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingEvent } from '../bookings/domain/booking-event.entity';
import { BookingsModule } from '../bookings/bookings.module';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { MatchingModule } from '../matching/matching.module';
import { DomainNotificationsModule } from '../notifications/domain/domain-notifications.module';
import { TrustModule } from '../trust/trust.module';
import { EmergencyDispatch } from './emergency-dispatch.entity';
import {
  EmergencyAdminController,
  EmergencyController,
} from './emergency.controller';
import { EmergencyService } from './emergency.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      EmergencyDispatch,
      Booking,
      BookingEvent,
      ServiceCategoryEntity,
    ]),
    BookingsModule,
    MatchingModule,
    DomainNotificationsModule,
    TrustModule,
  ],
  controllers: [EmergencyController, EmergencyAdminController],
  providers: [EmergencyService],
  exports: [EmergencyService],
})
export class EmergencyModule {}
