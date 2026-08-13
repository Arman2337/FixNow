import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import {
  IsEnum,
  IsNumber,
  IsInt,
  Max,
  Min,
  IsOptional,
  IsString,
  MinLength,
  validateSync,
} from 'class-validator';

export enum Environment {
  Development = 'development',
  Production = 'production',
  Test = 'test',
}

export class EnvironmentVariables {
  @IsEnum(Environment)
  @IsOptional()
  NODE_ENV: Environment = Environment.Development;

  @IsNumber()
  @IsOptional()
  PORT: number = 3000;

  @IsString()
  @IsOptional()
  LOG_LEVEL: string = 'info';

  @IsString()
  DATABASE_URL: string;

  @IsString()
  REDIS_URL: string;

  @IsString()
  @MinLength(32)
  JWT_SECRET: string;

  @IsString()
  @MinLength(32)
  OTP_SECRET: string;

  @IsString()
  @IsOptional()
  REALTIME_ALLOWED_ORIGINS?: string;

  @IsString()
  @IsOptional()
  WEB_ALLOWED_ORIGINS?: string;

  @IsInt()
  @Min(10_000)
  @Max(15_000)
  @IsOptional()
  LOCATION_UPDATE_INTERVAL_MS: number = 10_000;

  @IsInt()
  @Min(1_000)
  @IsOptional()
  LOCATION_STALE_AFTER_MS: number = 60_000;

  @IsInt()
  @Min(1_000)
  @IsOptional()
  LOCATION_CACHE_TTL_MS: number = 60_000;

  @IsInt()
  @Min(5_000)
  @IsOptional()
  LOCATION_PRESENCE_TTL_MS: number = 45_000;

  @IsInt()
  @Min(60_000)
  @IsOptional()
  LOCATION_CONSENT_TTL_MS: number = 43_200_000;

  @IsNumber()
  @Min(1)
  @Max(1_000)
  @IsOptional()
  LOCATION_MAX_ACCURACY_METERS: number = 100;

  @IsString()
  @MinLength(1)
  @IsOptional()
  LOCATION_NOTICE_VERSION: string = '2026-08-13';

  @IsString()
  @IsOptional()
  SMTP_HOST?: string;

  @IsNumber()
  @IsOptional()
  SMTP_PORT: number = 587;

  @IsString()
  @IsOptional()
  SMTP_USER?: string;

  @IsString()
  @IsOptional()
  SMTP_PASS?: string;

  @IsString()
  @IsOptional()
  SMTP_FROM?: string;
}

export function validate(config: Record<string, unknown>) {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });

  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    throw new Error(errors.toString());
  }
  validateRealtimeOrigins(validatedConfig);
  validateWebOrigins(validatedConfig);
  if (
    validatedConfig.LOCATION_CACHE_TTL_MS >
    validatedConfig.LOCATION_STALE_AFTER_MS
  ) {
    throw new Error(
      'LOCATION_CACHE_TTL_MS must not exceed LOCATION_STALE_AFTER_MS',
    );
  }
  return validatedConfig;
}

function validateWebOrigins(config: EnvironmentVariables): void {
  validateOriginList(config, config.WEB_ALLOWED_ORIGINS, 'WEB_ALLOWED_ORIGINS');
}

function validateRealtimeOrigins(config: EnvironmentVariables): void {
  validateOriginList(
    config,
    config.REALTIME_ALLOWED_ORIGINS,
    'REALTIME_ALLOWED_ORIGINS',
  );
}

function validateOriginList(
  config: EnvironmentVariables,
  values: string | undefined,
  name: string,
): void {
  if (!values) return;
  for (const value of values.split(',')) {
    let origin: URL;
    try {
      origin = new URL(value.trim());
    } catch {
      throw new Error(`${name} must contain valid origins`);
    }
    const secure = origin.protocol === 'https:';
    const localDevelopment =
      config.NODE_ENV !== Environment.Production &&
      origin.protocol === 'http:' &&
      ['localhost', '127.0.0.1', '::1'].includes(origin.hostname);
    if (
      (!secure && !localDevelopment) ||
      origin.username ||
      origin.password ||
      origin.pathname !== '/' ||
      origin.search ||
      origin.hash
    ) {
      throw new Error(
        `${name} must use HTTPS origins (loopback HTTP is allowed outside production)`,
      );
    }
  }
}
