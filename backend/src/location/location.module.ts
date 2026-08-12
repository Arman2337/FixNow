import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { ProviderAvailabilityEntity } from '../providers/availability/provider-availability.entity';
import { LocationService } from './location.service';

@Module({
  imports: [TypeOrmModule.forFeature([Booking, ProviderAvailabilityEntity])],
  providers: [LocationService],
  exports: [LocationService],
})
export class LocationModule {}
