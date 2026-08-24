import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import type {
  ScheduleAction,
  ScheduleCadence,
} from '../../../shared/recurring.types';

export class CreateScheduleDto {
  @IsUUID()
  serviceCategoryId!: string;

  @IsString()
  @MaxLength(2000)
  description!: string;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  locationLat!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  locationLng!: number;

  @IsIn(['WEEKLY', 'MONTHLY'])
  cadence!: ScheduleCadence;

  /** First occurrence as a UTC instant; must be in the future. */
  @IsDateString()
  firstOccurrenceAt!: string;
}

export class UpdateScheduleStatusDto {
  @IsIn(['pause', 'resume', 'cancel'])
  action!: ScheduleAction;
}
