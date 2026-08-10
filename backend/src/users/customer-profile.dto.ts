import { Transform, type TransformFnParams } from 'class-transformer';
import { IsString, Length, Matches } from 'class-validator';

export class UpdateCustomerProfileDto {
  @Transform(({ value }: TransformFnParams): unknown => {
    const candidate: unknown = value;
    return typeof candidate === 'string' ? candidate.trim() : candidate;
  })
  @IsString()
  @Length(1, 80)
  @Matches(/^[^\p{Cc}]+$/u)
  displayName!: string;
}

export interface CustomerProfileResponse {
  displayName: string | null;
}
