import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  PAYMENT_GATEWAY,
  FakePaymentGateway,
  RazorpayPaymentGateway,
} from './payment-gateway';
import { PaymentOrder } from './domain/payment-order.entity';
import { PaymentEvent } from './domain/payment-event.entity';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

export enum PaymentProviderName {
  Fake = 'fake',
  Razorpay = 'razorpay',
}

@Module({
  imports: [TypeOrmModule.forFeature([PaymentOrder, PaymentEvent])],
  controllers: [PaymentsController],
  providers: [
    FakePaymentGateway,
    RazorpayPaymentGateway,
    PaymentsService,
    {
      provide: PAYMENT_GATEWAY,
      useFactory: (
        razorpay: RazorpayPaymentGateway,
        fake: FakePaymentGateway,
        config: ConfigService,
      ) => {
        const provider = config.get<string>('PAYMENT_PROVIDER');
        return provider === PaymentProviderName.Razorpay ? razorpay : fake;
      },
      inject: [RazorpayPaymentGateway, FakePaymentGateway, ConfigService],
    },
  ],
  exports: [PAYMENT_GATEWAY],
})
export class PaymentsModule {}
