import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from './domain/booking.entity';
import { BookingEvent } from './domain/booking-event.entity';
import { BookingMessage } from './domain/booking-message.entity';
import { RecurringSchedule } from './domain/recurring-schedule.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { BookingsController } from './bookings.controller';
import { SchedulesController } from './schedules.controller';
import { BookingMessagesController } from './booking-messages.controller';
import { BookingsService } from './bookings.service';
import { SchedulesService } from './schedules.service';
import { BookingMessagesService } from './booking-messages.service';
import { MatchingModule } from '../matching/matching.module';
import { LocationModule } from '../location/location.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { DomainNotificationsModule } from '../notifications/domain/domain-notifications.module';
import { TrustModule } from '../trust/trust.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Booking,
      BookingEvent,
      BookingMessage,
      RecurringSchedule,
      ServiceCategoryEntity,
    ]),
    MatchingModule,
    LocationModule,
    RealtimeModule,
    DomainNotificationsModule,
    TrustModule,
  ],
  controllers: [
    BookingsController,
    SchedulesController,
    BookingMessagesController,
  ],
  providers: [
    BookingsService,
    SchedulesService,
    BookingMessagesService,
  ],
  exports: [TypeOrmModule, BookingsService, BookingMessagesService],
})
export class BookingsModule {}
