import {
  Equals,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  Min,
  MinLength,
} from 'class-validator';

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

export class CreateRefundDto {
  /** Partial refund when present; full refund otherwise. Integer paise. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100_000_00)
  amountMinor?: number;

  @IsString()
  @MinLength(3)
  reason!: string;
}

export class ConfirmGroupServiceDto {
  @Equals(true)
  serviceReceived!: boolean;
}

export class CheckoutTokenDto {
  @Matches(
    /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}\.\d{10}\.[a-f0-9]{64}$/,
  )
  token!: string;
}
