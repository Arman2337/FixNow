import {
  IsBoolean,
  IsOptional,
  IsString,
  IsInt,
  Min,
  Max,
  IsUUID,
} from 'class-validator';
import { Transform } from 'class-transformer';
import {
  LIST_ENDPOINT_MAX_LIMIT,
  coerceOptionalLimit,
} from '../common/list-pagination.dto';

export class ProviderSkillQueryDto {
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isVerified?: boolean;

  @IsOptional()
  @IsUUID()
  serviceCategoryId?: string;

  /**
   * API-003. Optional rather than defaulted, so an internal caller can pass
   * `{ isVerified: true }` and let the service apply the bound. A `= …`
   * default here would be required in the type but only applied at runtime
   * through the ValidationPipe, which breaks every literal construction of
   * this DTO in code and in tests.
   */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(LIST_ENDPOINT_MAX_LIMIT)
  @Transform(coerceOptionalLimit)
  limit?: number;
}

export class CreateProviderSkillDto {
  @IsUUID()
  serviceCategoryId!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(50)
  yearsExperience?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000) // $1M max
  hourlyRateCents?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000) // $1M max
  visitFeeCents?: number;

  @IsOptional()
  @IsString()
  description?: string;
}

export class UpdateProviderSkillDto {
  @IsOptional()
  @IsUUID()
  serviceCategoryId?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(50)
  yearsExperience?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000)
  hourlyRateCents?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000)
  visitFeeCents?: number;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsBoolean()
  isVerified?: boolean;

  @IsOptional()
  @IsString()
  verificationNotes?: string;
}

export class VerifyProviderSkillDto {
  @IsBoolean()
  isVerified!: boolean;

  @IsOptional()
  @IsString()
  verificationNotes?: string;
}

export class ProviderSkillResponseDto {
  id!: string;

  userId!: string;

  serviceCategoryId!: string;

  yearsExperience!: number | null;

  hourlyRateCents!: number | null;

  visitFeeCents!: number | null;

  description!: string | null;

  isVerified!: boolean;

  verificationNotes!: string | null;

  createdAt!: Date;

  updatedAt!: Date;

  serviceCategory?: {
    id: string;
    name: string;
    slug: string;
    description: string | null;
    iconName: string | null;
    isEmergency: boolean;
  };
}

export class ProviderSkillsCountDto {
  total!: number;

  verified!: number;
}
