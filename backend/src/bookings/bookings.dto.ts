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
  IsArray,
  ArrayMaxSize,
  ArrayMinSize,
  ValidateNested,
  MaxLength,
  Matches,
} from 'class-validator';
import { Type } from 'class-transformer';
import {
  BookingStatus,
  CreateBookingRequest,
  CreateBookingLineItemRequest,
  UpdateBookingItemsRequest,
} from '../../../shared/booking-lifecycle.types';

export class CreateBookingLineItemDto implements CreateBookingLineItemRequest {
  @IsUUID()
  @IsNotEmpty()
  subServiceId: string;

  @IsInt()
  @Min(1)
  quantity: number;
}

export class BookingItemDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  id: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  name: string;

  @IsInt()
  @Min(1)
  @Max(99)
  quantity: number;

  @IsInt()
  @Min(0)
  unitPriceMinor: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  durationMinutes?: number | null;
}

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

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => BookingItemDto)
  items?: BookingItemDto[] | null;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateBookingLineItemDto)
  lineItems?: CreateBookingLineItemDto[];
}

export class UpdateBookingLineItemsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateBookingLineItemDto)
  lineItems: CreateBookingLineItemDto[];

  @IsInt()
  @Min(1)
  expectedVersion: number;
}

export class UpdateBookingStatusDto {
  @IsEnum(BookingStatus)
  status: BookingStatus;

  @IsInt()
  @Min(1)
  expectedVersion: number;
}

export class UpdateBookingItemsDto implements UpdateBookingItemsRequest {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => BookingItemDto)
  items: BookingItemDto[];

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

export class RescheduleBookingDto {
  @IsDateString()
  @IsNotEmpty()
  newScheduledAt: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsInt()
  @Min(1)
  expectedVersion: number;
}

export class AcceptBookingDto {
  @IsInt()
  @Min(1)
  expectedVersion: number;
}

export class VerifyServiceStartOtpDto {
  @IsString()
  @Matches(/^\d{4}$/)
  otp: string;

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
