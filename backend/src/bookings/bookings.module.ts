import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from './domain/booking.entity';
import { BookingEvent } from './domain/booking-event.entity';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { MatchingModule } from '../matching/matching.module';

@Module({
  imports: [TypeOrmModule.forFeature([Booking, BookingEvent]), MatchingModule],
  controllers: [BookingsController],
  providers: [BookingsService],
  exports: [TypeOrmModule, BookingsService],
})
export class BookingsModule {}
