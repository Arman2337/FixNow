import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingReview } from './domain/review.entity';
import { ReviewModerationEvent } from './domain/review-moderation-event.entity';
import { RatingsController } from './ratings.controller';
import { RatingsAdminController } from './ratings-admin.controller';
import { RatingsService } from './ratings.service';
import { ReviewPhotosService } from './review-photos.service';
import { ReviewPhoto } from './domain/review-photo.entity';
import { ReviewPhotoModerationEvent } from './domain/review-photo-moderation-event.entity';
import { ProvidersModule } from '../providers/providers.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Booking,
      BookingReview,
      ReviewModerationEvent,
      ReviewPhoto,
      ReviewPhotoModerationEvent,
    ]),
    ProvidersModule,
  ],
  controllers: [RatingsController, RatingsAdminController],
  providers: [RatingsService, ReviewPhotosService],
  exports: [RatingsService],
})
export class RatingsModule {}
