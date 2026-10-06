import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from './domain/booking.entity';
import { BookingEvent } from './domain/booking-event.entity';
import { BookingMessage } from './domain/booking-message.entity';
import { BookingCall } from './domain/booking-call.entity';
import { BookingLineItem } from './domain/booking-line-item.entity';
import { RecurringSchedule } from './domain/recurring-schedule.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { BookingsController } from './bookings.controller';
import { SchedulesController } from './schedules.controller';
import { BookingMessagesController } from './booking-messages.controller';
import { BookingCallsController } from './booking-calls.controller';
import { BookingsService } from './bookings.service';
import { SchedulesService } from './schedules.service';
import { BookingMessagesService } from './booking-messages.service';
import { BookingCallsService } from './booking-calls.service';
import { BookingDispatchHandlers } from './booking-dispatch.handlers';
import { MatchingModule } from '../matching/matching.module';
import { ProvidersModule } from '../providers/providers.module';
import { LocationModule } from '../location/location.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { DomainNotificationsModule } from '../notifications/domain/domain-notifications.module';
import { TrustModule } from '../trust/trust.module';
import { OutboxModule } from '../outbox/outbox.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Booking,
      BookingLineItem,
      BookingEvent,
      BookingMessage,
      BookingCall,
      RecurringSchedule,
      ServiceCategoryEntity,
    ]),
    MatchingModule,
    // Provides ProviderCapacityService, which enforces the BUG-008 concurrent
    // booking limit. ProvidersModule does not import BookingsModule, so this
    // introduces no cycle.
    ProvidersModule,
    LocationModule,
    RealtimeModule,
    DomainNotificationsModule,
    TrustModule,
    // FN-082. The booking transaction records the fan-out intent here rather
    // than performing it, and BookingDispatchHandlers drains it.
    OutboxModule,
  ],
  // Route registration order is load-bearing. Nest registers a module's routes
  // in the order its controllers are listed here, and Express matches in
  // registration order, so `BookingsController`'s `@Get(':id')` used to be
  // registered before `SchedulesController`'s `@Get()`. A `GET
  // /api/v1/bookings/schedules` therefore matched `:id` with the literal
  // string "schedules", and the lookup reached PostgreSQL as
  // `invalid input syntax for type uuid: "schedules"` — a 500 that the mobile
  // client surfaced as "Repeating services are unavailable".
  //
  // `SchedulesController` is listed first so the literal path wins. The
  // `ParseUUIDPipe` on `BookingsController`'s `:id` routes is the second half
  // of the same fix: even if this ordering is disturbed again, a non-UUID path
  // segment is refused with a 400 at the edge instead of reaching the database.
  controllers: [
    SchedulesController,
    BookingsController,
    BookingMessagesController,
    BookingCallsController,
  ],
  providers: [
    BookingsService,
    SchedulesService,
    BookingMessagesService,
    BookingCallsService,
    BookingDispatchHandlers,
  ],
  exports: [
    TypeOrmModule,
    BookingsService,
    BookingMessagesService,
    BookingCallsService,
  ],
})
export class BookingsModule {}
