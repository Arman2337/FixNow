import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsString,
  Length,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RequestOtpDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  email!: string;
}

export class VerifyOtpDto extends RequestOtpDto {
  @IsString()
  @Length(6, 6)
  code!: string;
}

export class RefreshTokenDto {
  @IsString()
  @MinLength(32)
  @MaxLength(512)
  refreshToken!: string;
}
