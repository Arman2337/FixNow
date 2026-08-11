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

export class ProviderSkillQueryDto {
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isVerified?: boolean;

  @IsOptional()
  @IsUUID()
  serviceCategoryId?: string;
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
