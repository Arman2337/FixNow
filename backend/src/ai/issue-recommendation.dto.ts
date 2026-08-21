import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class IssueRecommendationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  description!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  clarificationContext?: string;
}
