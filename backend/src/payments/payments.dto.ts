import { IsString, IsUUID } from 'class-validator';

export class CreatePaymentOrderDto {
  @IsUUID()
  bookingId!: string;
}

export class VerifyPaymentDto {
  @IsUUID()
  orderId!: string;

  @IsString()
  razorpayPaymentId!: string;

  @IsString()
  razorpaySignature!: string;
}
