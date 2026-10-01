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
  BookingItemRequestContract,
  CreateBookingRequest,
  CreateBookingLineItemRequest,
  UpdateBookingItemsRequest,
  PROVIDER_ABANDONMENT_REASONS,
  type ProviderAbandonmentReason,
} from '../../../shared/booking-lifecycle.types';

export class CreateBookingLineItemDto implements CreateBookingLineItemRequest {
  @IsUUID()
  @IsNotEmpty()
  subServiceId: string;

  @IsInt()
  @Min(1)
  quantity: number;
}

/**
 * One itemized task line as a CLIENT may send it.
 *
 * SECURITY (SEC-001): this shape deliberately has no `unitPriceMinor` and no
 * `name`. The client chooses a catalogue entry and a quantity; the backend
 * resolves the name, unit price and duration from `sub_services`. The priced
 * snapshot (`BookingItemContract`) is an output-only shape.
 *
 * `forbidNonWhitelisted: true` is set globally, so a client that still posts
 * `unitPriceMinor` receives a 400 rather than having it silently ignored.
 */
export class BookingItemRequestDto implements BookingItemRequestContract {
  @IsUUID()
  @IsNotEmpty()
  subServiceId: string;

  @IsInt()
  @Min(1)
  @Max(99)
  quantity: number;
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
  @Type(() => BookingItemRequestDto)
  items?: BookingItemRequestDto[] | null;

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
  @Type(() => BookingItemRequestDto)
  items: BookingItemRequestDto[];

  @IsInt()
  @Min(1)
  expectedVersion: number;

  /** Recorded on the audit trail so a price change is never silent. */
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason?: string;
}

export class CancelBookingDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason: string;

  @IsInt()
  @Min(1)
  expectedVersion: number;

  /**
   * BUG-020. Required when a provider abandons a job they have started.
   *
   * Optional for everyone else: a customer cancelling a request has no reason
   * code to give, and an admin cancelling has their own vocabulary. Making it
   * universally required would push a meaningless value into every cancellation
   * just to satisfy a rule that only applies to one path.
   *
   * The service enforces "required when `IN_PROGRESS` and the caller is the
   * provider" - a DTO cannot see either of those, and a validation rule that
   * could not express its own condition would be enforced in the wrong place.
   */
  @IsOptional()
  @IsEnum(PROVIDER_ABANDONMENT_REASONS)
  abandonmentReason?: ProviderAbandonmentReason;
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
