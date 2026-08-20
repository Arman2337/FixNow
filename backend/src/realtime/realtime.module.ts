import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeTelemetryService } from './realtime-telemetry.service';
import { LocationModule } from '../location/location.module';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingProjectionService } from './booking-projection.service';
import { BoundedFallbackEtaAdapter, EtaAdapter } from './eta-adapter';
import { OpenRouteServiceAdapter, RouteAdapter } from './route-adapter';

@Module({
  imports: [AuthModule, LocationModule, TypeOrmModule.forFeature([Booking])],
  providers: [
    RealtimeGateway,
    RealtimeConnectionRegistry,
    RealtimeTelemetryService,
    BookingProjectionService,
    BoundedFallbackEtaAdapter,
    OpenRouteServiceAdapter,
    { provide: EtaAdapter, useExisting: BoundedFallbackEtaAdapter },
    { provide: RouteAdapter, useExisting: OpenRouteServiceAdapter },
  ],
  exports: [RealtimeTelemetryService, BookingProjectionService],
})
export class RealtimeModule {}
