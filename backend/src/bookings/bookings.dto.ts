import {
  IsString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsDateString,
  Min,
  Max,
  IsUUID,
  IsInt,
  IsEnum,
  MaxLength,
  Matches,
} from 'class-validator';
import { Type } from 'class-transformer';
import {
  BookingStatus,
  CreateBookingRequest,
} from '../../../shared/booking-lifecycle.types';

export class CreateBookingDto implements CreateBookingRequest {
  @IsUUID()
  @IsNotEmpty()
  serviceCategoryId: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
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
  scheduledAt?: string | null;
}

export class UpdateBookingStatusDto {
  @IsEnum(BookingStatus)
  status: BookingStatus;

  @IsInt()
  @Min(1)
  expectedVersion: number;
}

export class CancelBookingDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason: string;

  @IsInt()
  @Min(1)
  expectedVersion: number;
}

export class AcceptBookingDto {
  @IsInt()
  @Min(1)
  expectedVersion: number;
}

export class BookingHistoryQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 10;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  @Matches(/^[A-Za-z0-9_-]+$/)
  cursor?: string;
}

export class AvailableBookingQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 20;
}
