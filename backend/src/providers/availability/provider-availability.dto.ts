import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  AvailabilityException,
  AvailabilityInterval,
  ProviderAvailabilityStatus,
  WeeklyAvailabilityRule,
} from '../../../../shared/provider-availability.types';

export class AvailabilityIntervalDto implements AvailabilityInterval {
  @IsInt()
  @Min(0)
  @Max(1439)
  startMinute!: number;

  @IsInt()
  @Min(1)
  @Max(1440)
  endMinute!: number;
}
export class WeeklyAvailabilityRuleDto implements WeeklyAvailabilityRule {
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek!: number;

  @IsArray()
  @ArrayMaxSize(12)
  @ValidateNested({ each: true })
  @Type(() => AvailabilityIntervalDto)
  intervals!: AvailabilityIntervalDto[];
}

export class AvailabilityExceptionDto implements AvailabilityException {
  @IsDateString({ strict: true })
  date!: string;

  @IsBoolean()
  unavailable!: boolean;

  @IsArray()
  @ArrayMaxSize(12)
  @ValidateNested({ each: true })
  @Type(() => AvailabilityIntervalDto)
  intervals!: AvailabilityIntervalDto[];
}

export class UpdateProviderScheduleDto {
  @IsString()
  @MaxLength(100)
  timeZone!: string;

  @IsArray()
  @ArrayMaxSize(7)
  @ValidateNested({ each: true })
  @Type(() => WeeklyAvailabilityRuleDto)
  weeklyRules!: WeeklyAvailabilityRuleDto[];

  @IsArray()
  @ArrayMaxSize(90)
  @ValidateNested({ each: true })
  @Type(() => AvailabilityExceptionDto)
  exceptions!: AvailabilityExceptionDto[];

  @IsInt()
  @Min(0)
  expectedVersion!: number;
}

export class UpdateProviderStatusDto {
  @IsEnum(ProviderAvailabilityStatus)
  status!: ProviderAvailabilityStatus;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;

  @IsInt()
  @Min(0)
  expectedVersion!: number;
}

export class ProviderAvailabilityResponseDto {
  id!: string;
  userId!: string;
  timeZone!: string;
  weeklyRules!: WeeklyAvailabilityRule[];
  exceptions!: AvailabilityException[];
  status!: ProviderAvailabilityStatus;
  statusExpiresAt!: Date | null;
  version!: number;
  createdAt!: Date;
  updatedAt!: Date;
}
