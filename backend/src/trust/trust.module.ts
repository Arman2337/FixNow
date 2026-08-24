import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingReview } from '../ratings/domain/review.entity';
import { Complaint } from '../support/complaints/domain/complaint.entity';
import { TrustSignal } from './domain/trust-signal.entity';
import { TrustService } from './trust.service';
import { TrustAdminController } from './trust-admin.controller';
import { TrustController } from './trust.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Booking, BookingReview, Complaint, TrustSignal]),
  ],
  controllers: [TrustAdminController, TrustController],
  providers: [TrustService],
  exports: [TrustService, TypeOrmModule],
})
export class TrustModule {}
