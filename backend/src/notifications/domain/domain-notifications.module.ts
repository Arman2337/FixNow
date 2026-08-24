import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PushDeviceTokenEntity } from '../push/push-device-token.entity';
import { PushModule } from '../push/push.module';
import { DomainNotificationService } from './domain-notification.service';
import { NotificationDelivery } from './notification-delivery.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([NotificationDelivery, PushDeviceTokenEntity]),
    PushModule,
  ],
  providers: [DomainNotificationService],
  exports: [DomainNotificationService],
})
export class DomainNotificationsModule {}
