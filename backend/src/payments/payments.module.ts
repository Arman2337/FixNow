import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  PAYMENT_GATEWAY,
  FakePaymentGateway,
  RazorpayPaymentGateway,
} from './payment-gateway';

export enum PaymentProviderName {
  Fake = 'fake',
  Razorpay = 'razorpay',
}

@Module({
  providers: [
    FakePaymentGateway,
    RazorpayPaymentGateway,
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
