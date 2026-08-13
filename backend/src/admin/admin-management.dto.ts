import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { ProviderOnboardingStatus } from '../providers/provider-onboarding-status';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';

export class AdminPageQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(50) limit = 20;
  @IsOptional() @IsString() @MaxLength(500) cursor?: string;
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @MaxLength(100)
  search?: string;
}

export class ProviderApplicationPageQueryDto extends AdminPageQueryDto {
  @IsOptional()
  @IsIn(Object.values(ProviderOnboardingStatus))
  status?: ProviderOnboardingStatus;
}

export class ClaimReviewDto {
  @Type(() => Number) @IsInt() @Min(0) expectedVersion!: number;
}

export class ReviewDecisionDto extends ClaimReviewDto {
  @IsIn([
    ProviderOnboardingStatus.Approved,
    ProviderOnboardingStatus.Rejected,
    ProviderOnboardingStatus.ResubmissionRequested,
  ])
  decision!: ProviderOnboardingStatus;
  @IsString() @Length(3, 1000) reason!: string;
}

export class ApplicationIdParamDto {
  @IsUUID() applicationId!: string;
}
export class DocumentParamDto extends ApplicationIdParamDto {
  @IsUUID() documentId!: string;
}
export class UserIdParamDto {
  @IsUUID() userId!: string;
}
export class BookingPageQueryDto extends AdminPageQueryDto {
  @IsOptional() @IsIn(Object.values(BookingStatus)) status?: BookingStatus;
}
export class BookingIdParamDto {
  @IsUUID() bookingId!: string;
}
export class AdminCancelBookingDto {
  @Type(() => Number) @IsInt() @Min(1) expectedVersion!: number;
  @IsString() @Length(3, 500) reason!: string;
}
