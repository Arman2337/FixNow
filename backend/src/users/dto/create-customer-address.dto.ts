import {
  IsBoolean,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Length,
  MaxLength,
} from 'class-validator';

/**
 * SEC-011: this body was a bare TypeScript `type`.
 *
 * NestJS's `ValidationPipe` validates only when the target's metatype is a
 * class. A `type` alias is erased at runtime, so the pipe's `toValidate()`
 * returned false and the whole body passed through unvalidated — `latitude` and
 * `longitude` were written straight to `customer_addresses` as whatever number
 * the client sent.
 *
 * That matters because this is the address a booking gets dispatched to and the
 * point map matching measures distance from. A latitude of 999, or of `NaN` from
 * a `?latitude=` query with no value, becomes a row that every subsequent
 * distance query has to reason about.
 *
 * The latitude/longitude bounds are the point of this class; the string fields
 * are bounded here too because `customer_addresses` has varchar limits and an
 * unbounded string on a customer-facing route is a write-amplification lever.
 */
export class CreateCustomerAddressDto {
  @IsOptional()
  @IsBoolean({ message: 'isDefault must be a boolean, not a string' })
  isDefault?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(50, { message: 'label must be at most 50 characters' })
  label?: string | null;

  @IsString()
  @Length(1, 255, { message: 'street must be between 1 and 255 characters' })
  street!: string;

  @IsString()
  @Length(1, 100, { message: 'city must be between 1 and 100 characters' })
  city!: string;

  @IsString()
  @Length(1, 100, { message: 'state must be between 1 and 100 characters' })
  state!: string;

  @IsString()
  @Length(1, 20, { message: 'zip must be between 1 and 20 characters' })
  zip!: string;

  @IsLatitude({ message: 'latitude must be a number between -90 and 90' })
  latitude!: number;

  @IsLongitude({ message: 'longitude must be a number between -180 and 180' })
  longitude!: number;
}
