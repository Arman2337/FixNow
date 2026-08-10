import { Module } from '@nestjs/common';
import { OTP_DELIVERY, SmtpOtpDelivery } from './otp-delivery';

@Module({
  providers: [
    SmtpOtpDelivery,
    { provide: OTP_DELIVERY, useExisting: SmtpOtpDelivery },
  ],
  exports: [OTP_DELIVERY],
})
export class NotificationsModule {}
