import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PushDeviceTokenEntity } from './push-device-token.entity';
import {
  PUSH_DELIVERY,
  DisabledPushDelivery,
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
    DisabledPushDelivery,
    FakePushDelivery,
    FcmPushDelivery,
    {
      provide: PUSH_DELIVERY,
      useFactory: (
        fcm: FcmPushDelivery,
        fake: FakePushDelivery,
        disabled: DisabledPushDelivery,
        config: ConfigService,
      ) => {
        // `disabled` must map to the honest no-op. Falling back to the fake
        // provider here made every notification look SENT in a default or
        // misconfigured environment while nothing was delivered.
        switch (config.get<string>('PUSH_PROVIDER')) {
          case PushProviderName.Fcm:
            return fcm;
          case PushProviderName.Fake:
            return fake;
          default:
            return disabled;
        }
      },
      inject: [
        FcmPushDelivery,
        FakePushDelivery,
        DisabledPushDelivery,
        ConfigService,
      ],
    },
  ],
  exports: [PUSH_DELIVERY],
})
export class PushModule {}
