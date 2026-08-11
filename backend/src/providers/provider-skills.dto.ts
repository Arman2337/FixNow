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
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ProviderSkillQueryDto {
  @ApiPropertyOptional({ description: 'Filter by verification status' })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isVerified?: boolean;

  @ApiPropertyOptional({ description: 'Filter by service category ID' })
  @IsOptional()
  @IsUUID()
  serviceCategoryId?: string;
}

export class CreateProviderSkillDto {
  @ApiProperty({ description: 'Service category ID' })
  @IsUUID()
  serviceCategoryId!: string;

  @ApiPropertyOptional({ description: 'Years of experience', example: 5 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(50)
  yearsExperience?: number;

  @ApiPropertyOptional({ description: 'Hourly rate in cents', example: 5000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000) // $1M max
  hourlyRateCents?: number;

  @ApiPropertyOptional({ description: 'Visit fee in cents', example: 2500 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000) // $1M max
  visitFeeCents?: number;

  @ApiPropertyOptional({ description: 'Skill description and specialties' })
  @IsOptional()
  @IsString()
  description?: string;
}

export class UpdateProviderSkillDto {
  @ApiPropertyOptional({ description: 'Service category ID' })
  @IsOptional()
  @IsUUID()
  serviceCategoryId?: string;

  @ApiPropertyOptional({ description: 'Years of experience' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(50)
  yearsExperience?: number;

  @ApiPropertyOptional({ description: 'Hourly rate in cents' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000)
  hourlyRateCents?: number;

  @ApiPropertyOptional({ description: 'Visit fee in cents' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000000)
  visitFeeCents?: number;

  @ApiPropertyOptional({ description: 'Skill description and specialties' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ description: 'Verification status (Admin only)' })
  @IsOptional()
  @IsBoolean()
  isVerified?: boolean;

  @ApiPropertyOptional({ description: 'Verification notes (Admin only)' })
  @IsOptional()
  @IsString()
  verificationNotes?: string;
}

export class VerifyProviderSkillDto {
  @ApiProperty({ description: 'Whether the skill is verified' })
  @IsBoolean()
  isVerified!: boolean;

  @ApiPropertyOptional({ description: 'Verification notes' })
  @IsOptional()
  @IsString()
  verificationNotes?: string;
}

export class ProviderSkillResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  userId!: string;

  @ApiProperty()
  serviceCategoryId!: string;

  @ApiPropertyOptional()
  yearsExperience!: number | null;

  @ApiPropertyOptional()
  hourlyRateCents!: number | null;

  @ApiPropertyOptional()
  visitFeeCents!: number | null;

  @ApiPropertyOptional()
  description!: string | null;

  @ApiProperty()
  isVerified!: boolean;

  @ApiPropertyOptional()
  verificationNotes!: string | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;

  @ApiPropertyOptional({ description: 'Service category details' })
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
  @ApiProperty({ description: 'Total number of skills' })
  total!: number;

  @ApiProperty({ description: 'Number of verified skills' })
  verified!: number;
}
