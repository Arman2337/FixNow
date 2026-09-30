import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuaranteeClaim } from './domain/guarantee-claim.entity';
import { GuaranteesController } from './guarantees.controller';
import { GuaranteesService } from './guarantees.service';
import { BookingsModule } from '../bookings/bookings.module';
import { MatchingModule } from '../matching/matching.module';
import { AuthModule } from '../auth/auth.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([GuaranteeClaim]),
    BookingsModule,
    // BUG-011/SEC-007: re-service now proves the named provider is an active,
    // verified provider for the booking's category. MatchingModule has no
    // further imports, so this introduces no cycle.
    MatchingModule,
    AuthModule,
    UsersModule,
  ],
  controllers: [GuaranteesController],
  providers: [GuaranteesService],
  exports: [GuaranteesService],
})
export class GuaranteesModule {}
