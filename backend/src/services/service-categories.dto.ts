import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Min,
  Max,
  Length,
  ValidateNested,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';

/**
 * Admin-published flat base price for a category. Amount is in minor
 * currency units (paise for INR). Only INR is accepted until an approved
 * decision widens the supported set.
 */
export class CategoryPricingInput {
  @IsInt()
  @Min(0)
  @Max(10_000_00)
  amountMinor!: number;

  @IsIn(['INR'])
  currency!: 'INR';
}

export class ServiceCategoryQueryDto {
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isEmergency?: boolean;
}

export class CreateServiceCategoryDto {
  @IsString()
  @Length(1, 255)
  name!: string;

  @IsString()
  @Length(1, 255)
  slug!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  @Length(1, 100)
  iconName?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(9999)
  displayOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsBoolean()
  isEmergency?: boolean;

  /** Absent leaves the category without a published price. */
  @IsOptional()
  @ValidateNested()
  @Type(() => CategoryPricingInput)
  pricing?: CategoryPricingInput;
}

export class UpdateServiceCategoryDto {
  @IsOptional()
  @IsString()
  @Length(1, 255)
  name?: string;

  @IsOptional()
  @IsString()
  @Length(1, 255)
  slug?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  @Length(1, 100)
  iconName?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(9999)
  displayOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsBoolean()
  isEmergency?: boolean;

  /**
   * Absent leaves pricing unchanged; `null` clears it back to "price on
   * request"; an object sets or replaces it.
   */
  @IsOptional()
  @ValidateNested()
  @Type(() => CategoryPricingInput)
  pricing?: CategoryPricingInput | null;
}

export class ServiceCategoryResponseDto {
  id!: string;

  name!: string;

  slug!: string;

  description!: string | null;

  iconName!: string | null;

  displayOrder!: number;

  isActive!: boolean;

  isEmergency!: boolean;

  pricing!: { amountMinor: number; currency: string } | null;

  // The four aggregate signals below are always present on the read endpoints
  // (findAll/getActive/getEmergency/findById/findBySlug), which route through
  // the stats loader. They are optional because the create/update endpoints
  // return the freshly-saved category, which has no providers, availability, or
  // reviews yet — so those responses legitimately omit them.

  /** Verified providers with an active account offering this category. */
  verifiedProCount?: number;

  /** Of those verified providers, how many are online right now. */
  onlineProCount?: number;

  /** Average published-review rating (1–5), or null when there are none. */
  rating?: number | null;

  /** Number of published reviews behind {@link rating}. */
  reviewCount?: number;

  createdAt!: Date;

  updatedAt!: Date;
}
