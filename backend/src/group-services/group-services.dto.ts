import { Transform } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

function trim({ value }: { value: unknown }): unknown {
  return typeof value === 'string' ? value.trim() : value;
}

export class CreateGroupServiceDto {
  @Matches(/^[a-f0-9]{32}$/)
  requestKey!: string;

  @IsUUID('4')
  categoryId!: string;

  @Transform(trim)
  @MinLength(2)
  @MaxLength(120)
  area!: string;

  @IsOptional()
  @Transform(trim)
  @MinLength(5)
  @MaxLength(300)
  serviceAddress?: string;

  @IsOptional()
  @Transform(trim)
  @MinLength(3)
  @MaxLength(120)
  preferredSchedule?: string;

  @Transform(trim)
  @MinLength(3)
  @MaxLength(1000)
  description!: string;
}

export class JoinGroupServiceDto {
  @Matches(/^[a-f0-9]{48}$/)
  token!: string;

  @IsOptional()
  @Transform(trim)
  @MinLength(5)
  @MaxLength(300)
  serviceAddress?: string;
}

export class QuoteGroupServiceDto {
  @IsInt()
  @Min(2)
  @Max(100000000)
  regularMinor!: number;

  @IsInt()
  @Min(1)
  @Max(99999999)
  groupMinor!: number;

  @Transform(trim)
  @MinLength(3)
  @MaxLength(500)
  note!: string;
}

export class SelectGroupQuoteDto {
  @IsUUID('4')
  quoteId!: string;
}

export class UpdateGroupServiceStatusDto {
  @IsIn(['SCHEDULED', 'IN_PROGRESS', 'COMPLETED'])
  status!: 'SCHEDULED' | 'IN_PROGRESS' | 'COMPLETED';
}
