import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
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
