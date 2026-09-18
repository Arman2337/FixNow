import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuaranteeClaim } from './domain/guarantee-claim.entity';
import { GuaranteesController } from './guarantees.controller';
import { GuaranteesService } from './guarantees.service';
import { BookingsModule } from '../bookings/bookings.module';
import { AuthModule } from '../auth/auth.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([GuaranteeClaim]),
    BookingsModule,
    AuthModule,
    UsersModule,
  ],
  controllers: [GuaranteesController],
  providers: [GuaranteesService],
  exports: [GuaranteesService],
})
export class GuaranteesModule {}
