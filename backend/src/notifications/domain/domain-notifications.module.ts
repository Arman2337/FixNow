import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../../bookings/domain/booking.entity';
import { PushDeviceTokenEntity } from '../push/push-device-token.entity';
import { PushModule } from '../push/push.module';
import { BookingReminderService } from './booking-reminder.service';
import { DomainNotificationService } from './domain-notification.service';
import { NotificationDelivery } from './notification-delivery.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      NotificationDelivery,
      PushDeviceTokenEntity,
      Booking,
    ]),
    PushModule,
  ],
  providers: [DomainNotificationService, BookingReminderService],
  exports: [DomainNotificationService],
})
export class DomainNotificationsModule {}
