import {
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class UpsertProviderProfileDto {
  @IsString()
  @Length(2, 120)
  displayName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  bio?: string | null;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(1)
  @Max(100)
  serviceRadiusKm!: number;

  @IsLatitude()
  baseLatitude!: number;

  @IsLongitude()
  baseLongitude!: number;
}

export class CoverageCheckDto {
  @IsLatitude()
  latitude!: number;

  @IsLongitude()
  longitude!: number;
}

export class ProviderProfileResponseDto {
  id!: string;

  userId!: string;

  displayName!: string;

  bio!: string | null;

  serviceRadiusKm!: number;

  baseLatitude!: number;

  baseLongitude!: number;

  skillIds!: string[];

  createdAt!: Date;

  updatedAt!: Date;
}

export class CoverageCheckResponseDto {
  isWithinServiceArea!: boolean;
}
