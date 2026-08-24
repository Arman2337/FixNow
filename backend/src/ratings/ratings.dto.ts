import {
  IsInt,
  IsEnum,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  ReviewModerationStatus,
  type CreateReviewRequest,
} from '../../../shared/ratings.types';

export class CreateReviewDto implements CreateReviewRequest {
  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reviewText?: string;
}

export class ModerateReviewDto {
  @IsEnum(ReviewModerationStatus)
  moderationStatus: ReviewModerationStatus;
  @IsString()
  @MaxLength(500)
  reason: string;
}
