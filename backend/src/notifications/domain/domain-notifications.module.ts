import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from '../../bookings/domain/booking.entity';
import { PushDeviceTokenEntity } from '../push/push-device-token.entity';
import { PushModule } from '../push/push.module';
import { BookingReminderService } from './booking-reminder.service';
import { DomainNotificationService } from './domain-notification.service';
import { NotificationDelivery } from './notification-delivery.entity';

import { InAppNotification } from './in-app-notification.entity';
import { InboxController } from './inbox.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      NotificationDelivery,
      InAppNotification,
      PushDeviceTokenEntity,
      Booking,
    ]),
    PushModule,
  ],
  controllers: [InboxController],
  providers: [DomainNotificationService, BookingReminderService],
  exports: [DomainNotificationService],
})
export class DomainNotificationsModule {}
