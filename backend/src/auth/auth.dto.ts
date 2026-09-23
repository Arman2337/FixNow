import { Transform } from 'class-transformer';
import { IsEmail, IsString, MaxLength, MinLength, IsOptional } from 'class-validator';
import type { RoleCode } from '../common/authorization/permission-policies';

export class EmailPasswordDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(128)
  password!: string;

  @IsOptional()
  @IsString()
  mobile?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  fullName?: string;
}

export interface AuthenticationResponse {
  userId: string;
  role: RoleCode;
  accessToken: string;
  refreshToken: string;
  tokenType: 'Bearer';
  expiresIn: number;
}
