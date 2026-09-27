import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsString,
  MaxLength,
  MinLength,
  IsOptional,
} from 'class-validator';
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

/**
 * A request to start a password reset.
 *
 * Only the email address. The response is identical whether or not the address
 * has an account, so this cannot be used to enumerate users.
 */
export class PasswordResetRequestDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  email!: string;
}

/**
 * A password reset redemption.
 *
 * The same 12-128 character policy as registration, enforced by the same
 * bounds, so a reset cannot be used to set a password that registration would
 * have rejected.
 */
export class PasswordResetConfirmDto {
  /** 64 hex characters: 32 random bytes, base16. */
  @IsString()
  @MinLength(64)
  @MaxLength(64)
  token!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(128)
  newPassword!: string;
}

export interface AuthenticationResponse {
  userId: string;
  role: RoleCode;
  accessToken: string;
  refreshToken: string;
  tokenType: 'Bearer';
  expiresIn: number;
}
