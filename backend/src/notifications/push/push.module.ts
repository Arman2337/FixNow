import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PushDeviceTokenEntity } from './push-device-token.entity';
import {
  PUSH_DELIVERY,
  FakePushDelivery,
  FcmPushDelivery,
} from './push-delivery';
import { PushDeviceController } from './push.controller';
import { PushDeviceService } from './push.service';

export enum PushProviderName {
  Disabled = 'disabled',
  Fake = 'fake',
  Fcm = 'fcm',
}

@Module({
  imports: [TypeOrmModule.forFeature([PushDeviceTokenEntity])],
  controllers: [PushDeviceController],
  providers: [
    PushDeviceService,
    FakePushDelivery,
    FcmPushDelivery,
    {
      provide: PUSH_DELIVERY,
      useFactory: (
        fcm: FcmPushDelivery,
        fake: FakePushDelivery,
        config: ConfigService,
      ) => {
        const provider = config.get<string>('PUSH_PROVIDER');
        return provider === PushProviderName.Fcm ? fcm : fake;
      },
      inject: [FcmPushDelivery, FakePushDelivery, ConfigService],
    },
  ],
  exports: [PUSH_DELIVERY],
})
export class PushModule {}
