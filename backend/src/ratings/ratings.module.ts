import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingReview } from './domain/review.entity';
import { ReviewModerationEvent } from './domain/review-moderation-event.entity';
import { RatingsController } from './ratings.controller';
import { RatingsAdminController } from './ratings-admin.controller';
import { RatingsService } from './ratings.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Booking, BookingReview, ReviewModerationEvent]),
  ],
  controllers: [RatingsController, RatingsAdminController],
  providers: [RatingsService],
  exports: [RatingsService],
})
export class RatingsModule {}
