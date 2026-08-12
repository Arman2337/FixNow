import { IsString, IsNotEmpty, IsNumber, IsOptional, IsDateString, Min, Max, IsUUID, IsInt } from 'class-validator';
import { Type } from 'class-transformer';
import { CreateBookingRequest } from '../../../shared/booking-lifecycle.types';

export class CreateBookingDto implements CreateBookingRequest {
  @IsUUID()
  @IsNotEmpty()
  serviceCategoryId: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  locationLat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  locationLng: number;

  @IsOptional()
  @IsDateString()
  scheduledAt?: Date | null;
}

export class UpdateBookingStatusDto {
  @IsString()
  @IsNotEmpty()
  status: string; // Will be validated against enum in service or here. For now string.
}

export class CancelBookingDto {
  @IsString()
  @IsNotEmpty()
  reason: string;
}


export class BookingHistoryQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number = 10;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number = 0;
}
