import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from './domain/booking.entity';
import { BookingEvent } from './domain/booking-event.entity';
import { RecurringSchedule } from './domain/recurring-schedule.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { BookingsController } from './bookings.controller';
import { SchedulesController } from './schedules.controller';
import { BookingsService } from './bookings.service';
import { SchedulesService } from './schedules.service';
import { MatchingModule } from '../matching/matching.module';
import { LocationModule } from '../location/location.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Booking,
      BookingEvent,
      RecurringSchedule,
      ServiceCategoryEntity,
    ]),
    MatchingModule,
    LocationModule,
    RealtimeModule,
  ],
  controllers: [BookingsController, SchedulesController],
  providers: [BookingsService, SchedulesService],
  exports: [TypeOrmModule, BookingsService],
})
export class BookingsModule {}
