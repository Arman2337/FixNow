import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import {
  IsEnum,
  IsNumber,
  IsInt,
  Matches,
  Max,
  MaxLength,
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

export enum BooleanString {
  False = 'false',
  True = 'true',
}

export enum AiProviderName {
  Disabled = 'disabled',
  Fake = 'fake',
  HuggingFace = 'huggingface',
}

export enum PaymentProviderName {
  Fake = 'fake',
  Razorpay = 'razorpay',
}

export enum PushProviderName {
  Disabled = 'disabled',
  Fake = 'fake',
  Fcm = 'fcm',
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

  @IsEnum(BooleanString)
  @IsOptional()
  LOCAL_OTP_BYPASS_ENABLED: BooleanString = BooleanString.False;

  @IsString()
  @IsOptional()
  REALTIME_ALLOWED_ORIGINS?: string;

  @IsString()
  @IsOptional()
  WEB_ALLOWED_ORIGINS?: string;

  /**
   * How many reverse proxies sit in front of this app, for Express'
   * `trust proxy`. Unset means trust no proxy, which is the safe default: with
   * it unset, `req.ip` is the socket address, so a client cannot forge
   * `X-Forwarded-For` to escape the global rate-limit bucket (SEC-006).
   *
   * Set to the real hop count in production. A wrong value in the permissive
   * direction re-opens the spoofing hole, so this is a number, not "true".
   */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10)
  TRUST_PROXY_HOPS?: number;

  /**
   * Content-Security-Policy. The API serves JSON and a small set of static
   * assets, so the default is deliberately restrictive (OPS-003).
   */
  @IsString()
  @IsOptional()
  CSP_DIRECTIVES?: string;

  /**
   * How long a browser should remember that this origin is HTTPS-only. Ignored
   * outside production, where the app is normally reached over plain HTTP in
   * development and would otherwise be locked out of its own origin.
   */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(63072000)
  HSTS_MAX_AGE_SECONDS?: number;

  /**
   * Origins a customer-supplied evidence link may point at. Defaults to
   * WEB_ALLOWED_ORIGINS when unset, so a deployment only has to set this if
   * evidence is hosted somewhere the web app is not.
   */
  @IsString()
  @IsOptional()
  EVIDENCE_ALLOWED_ORIGINS?: string;

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

  /**
   * How many jobs a provider may hold at once (BUG-008). Previously unbounded,
   * so a provider could accept any number of concurrent bookings.
   */
  @IsInt()
  @Min(1)
  @Max(100)
  @IsOptional()
  PROVIDER_MAX_CONCURRENT_BOOKINGS: number = 5;

  @IsInt()
  @Min(60_000)
  @IsOptional()
  LOCATION_CONSENT_TTL_MS: number = 43_200_000;

  @IsNumber()
  @Min(1)
  // @Max(1_000)
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

  @IsString()
  @IsOptional()
  OPENROUTESERVICE_API_KEY?: string;

  // The free OpenRouteService plan allows 200 requests/day, so a live route is
  // refreshed only after the technician has moved this far (or the interval
  // below has elapsed). GPS jitter must not spend the daily quota.
  @IsNumber()
  @Min(1)
  @IsOptional()
  ROUTE_REFRESH_MIN_METERS: number = 50;

  @IsInt()
  @Min(1_000)
  @IsOptional()
  ROUTE_REFRESH_MIN_INTERVAL_MS: number = 60_000;

  @IsInt()
  @Min(1_000)
  @IsOptional()
  ROUTE_MAX_CACHE_AGE_MS: number = 600_000;

  @IsEnum(BooleanString)
  @IsOptional()
  AI_ENABLED: BooleanString = BooleanString.False;

  @IsEnum(AiProviderName)
  @IsOptional()
  AI_PROVIDER: AiProviderName = AiProviderName.Disabled;

  @IsString()
  @MinLength(1)
  @IsOptional()
  AI_MODEL: string = 'not-configured';

  @IsInt()
  @Min(100)
  @Max(30_000)
  @IsOptional()
  AI_TIMEOUT_MS: number = 3_000;

  @IsInt()
  @Min(1)
  @Max(2_048)
  @IsOptional()
  AI_MAX_OUTPUT_TOKENS: number = 256;

  @IsInt()
  @Min(1)
  @Max(100)
  @IsOptional()
  AI_REQUEST_RATE_LIMIT: number = 10;

  @IsInt()
  @Min(1_000)
  @Max(3_600_000)
  @IsOptional()
  AI_REQUEST_RATE_WINDOW_MS: number = 60_000;

  // --- Multimodal problem classification (FN-058 voice, FN-059 image) ---
  // Per-feature kill switches. Both default off; production enablement is
  // additionally gated on the ADR-0014 release gate (see docs/ai/).
  @IsEnum(BooleanString)
  @IsOptional()
  AI_VOICE_ENABLED: BooleanString = BooleanString.False;

  @IsEnum(BooleanString)
  @IsOptional()
  AI_VISION_ENABLED: BooleanString = BooleanString.False;

  @IsInt()
  @Min(1_024)
  @Max(33_554_432)
  @IsOptional()
  AI_MAX_IMAGE_BYTES: number = 8_388_608;

  @IsInt()
  @Min(1_024)
  @Max(52_428_800)
  @IsOptional()
  AI_MAX_AUDIO_BYTES: number = 15_728_640;

  // Hugging Face adapter settings. HF_TOKEN is server-side only and is never
  // returned to the client or logged. Required only when AI_PROVIDER=huggingface.
  @IsString()
  @IsOptional()
  HF_TOKEN?: string;

  @IsString()
  @MinLength(1)
  @IsOptional()
  HF_INFERENCE_BASE_URL: string = 'https://router.huggingface.co/v1';

  @IsString()
  @MinLength(1)
  @IsOptional()
  HF_ASR_BASE_URL: string = 'https://router.huggingface.co/hf-inference/models';

  @IsString()
  @MinLength(1)
  @IsOptional()
  HF_VISION_MODEL: string = 'Qwen/Qwen2.5-VL-72B-Instruct';

  @IsString()
  @MinLength(1)
  @IsOptional()
  HF_WHISPER_MODEL: string = 'openai/whisper-large-v3';

  @IsEnum(PushProviderName)
  @IsOptional()
  PUSH_PROVIDER: PushProviderName = PushProviderName.Disabled;

  @IsString()
  @IsOptional()
  FCM_CREDENTIALS_FILE?: string;

  @IsEnum(PaymentProviderName)
  @IsOptional()
  PAYMENT_PROVIDER: PaymentProviderName = PaymentProviderName.Fake;

  @IsString()
  @IsOptional()
  RAZORPAY_KEY_ID?: string;

  @IsString()
  @IsOptional()
  RAZORPAY_KEY_SECRET?: string;

  @IsString()
  @IsOptional()
  RAZORPAY_WEBHOOK_SECRET?: string;

  /**
   * Where provider identity documents are stored. Optional only outside
   * production, where it falls back to a local MinIO on loopback; in production
   * it is required and must be HTTPS. See validateObjectStorageEndpoint.
   */
  @IsString()
  @IsOptional()
  PROVIDER_DOCUMENT_S3_ENDPOINT?: string;

  /**
   * How many AI media uploads may be in flight at once, across all users.
   *
   * An implementation bound, not a policy number: each in-flight upload holds
   * up to 32 MiB (image) or 50 MiB (audio) resident in the Node heap while it
   * waits on the provider, so this caps peak memory. Text-only classification
   * takes no slot.
   */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(64)
  AI_MAX_CONCURRENT_MEDIA?: number;

  /**
   * SEC-013. The variables below were read straight from `process.env` in six
   * places and never appeared in this class, which meant they bypassed every
   * validator above: no type coercion, no bounds, no production rules. The
   * scanner in particular read `CLAMAV_PORT` through `Number()` on whatever
   * string arrived, so a typo produced `NaN` and a silently unreachable scanner
   * rather than a named configuration error.
   *
   * Declaring them here is what makes them real inputs. `validate()` then also
   * runs `assertNoUndeclaredEnvironment`, which fails the boot when the process
   * holds a variable this class does not declare — that is what stops the next
   * `process.env.X ?? 'default'` from reappearing unnoticed.
   */

  /** ClamAV daemon. Malware scanning fails closed, so a wrong host is fatal. */
  @IsOptional()
  @IsString()
  @MinLength(1)
  CLAMAV_HOST?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  CLAMAV_PORT?: number;

  /** Private bucket holding provider identity documents. */
  @IsOptional()
  @IsString()
  @MinLength(1)
  PROVIDER_DOCUMENT_BUCKET?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  PROVIDER_DOCUMENT_S3_REGION?: string;

  /** How long a quarantined document is retained before deletion. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3650)
  PROVIDER_DOCUMENT_RETENTION_DAYS?: number;

  /**
   * The UTC hour range notifications are held back, as `start-end`
   * (for example `22-7` for 10pm to 7am). Read as a string and parsed by a
   * regex because it is a range, not a duration.
   */
  @IsOptional()
  @IsString()
  @Matches(/^\s*\d{1,2}\s*-\s*\d{1,2}\s*$/, {
    message: 'NOTIFICATION_QUIET_HOURS_UTC must look like "22-7"',
  })
  NOTIFICATION_QUIET_HOURS_UTC?: string;

  /**
   * Operational intervals.
   *
   * These were each read through a `positiveEnv('KEY', fallback)` helper that
   * indexed `process.env` with a literal, so no validator ever saw them: a typo
   * in the key silently used the fallback, and a non-numeric value silently used
   * the fallback too. `scripts/check-env-declarations.ts` now resolves those call
   * sites against this class, which is what makes a typo in a key name a build
   * failure rather than a quiet default.
   *
   * They stay read from `process.env` at module scope because each backs a
   * module-level `setInterval` constant that is created during import — before
   * the DI graph exists and long before `validate()` runs. Declaring them here is
   * what makes them bounded and documented; the values are still read early.
   */

  /** How long a REQUESTED booking waits for a provider before expiring. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(86_400)
  REQUESTED_BOOKING_EXPIRY_SECONDS?: number;

  /** How often the emergency/booking sweeper runs. */
  @IsOptional()
  @IsInt()
  @Min(1_000)
  @Max(600_000)
  NOTIFICATION_REMINDER_INTERVAL_MS?: number;

  /** How far ahead of the appointment a reminder is sent. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1_440)
  NOTIFICATION_REMINDER_LEAD_MINUTES?: number;

  /** Outbox drain cadence. */
  @IsOptional()
  @IsInt()
  @Min(100)
  @Max(60_000)
  OUTBOX_DRAIN_INTERVAL_MS?: number;

  /** Redis dependency health-probe cadence. */
  @IsOptional()
  @IsInt()
  @Min(1_000)
  @Max(600_000)
  REDIS_HEALTH_INTERVAL_MS?: number;

  /**
   * Where unexpected errors are reported, as a Sentry DSN.
   *
   * Optional and off by default, because the structured log is already
   * authoritative and a third-party default would export data nobody chose to
   * export. When set, only the fields in `ErrorReport` are sent: no request body,
   * no headers, no customer object. That restriction is what makes it acceptable
   * to send anything at all.
   */
  @IsOptional()
  @IsString()
  @MinLength(8)
  ERROR_REPORTING_DSN?: string;

  /**
   * A build identifier attached to every error report, so a spike can be
   * attributed to a deploy rather than to "recently". Left unset rather than
   * derived from a timestamp, because a value that changes on every process
   * start would make every report look like a different release.
   */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  APP_RELEASE?: string;
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
  validateObjectStorageConfiguration(validatedConfig);
  validateRealtimeOrigins(validatedConfig);
  validateWebOrigins(validatedConfig);
  validateLocalOtpBypass(validatedConfig);
  validateAiConfiguration(validatedConfig);
  validatePushConfiguration(validatedConfig);
  validatePaymentConfiguration(validatedConfig);
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

/**
 * SEC-013. The list of variables the source is allowed to read outside this
 * class.
 *
 * The six variables this replaced were each read as `process.env.X ?? 'default'`
 * in one file, which meant they were never type-coerced, never bounded, and never
 * subject to a production rule. `CLAMAV_PORT` was the sharpest case: it went
 * through `Number()` on whatever string arrived, so a typo became `NaN` and a
 * silently unreachable malware scanner on a path that is supposed to fail
 * closed.
 *
 * Two of these still read `process.env` directly rather than going through
 * `ConfigService`, because they are constructed outside the DI graph:
 * `S3PrivateObjectStorage` builds its `S3Client` in a field initialiser, and the
 * storage access keys are deliberately never held on the validated config object
 * so they cannot leak into a log line or a `/health` payload. Declaring them here
 * is what makes them reviewed inputs; `scripts/check-env-declarations.ts` fails
 * the build on any *new* direct read.
 *
 * Note this is deliberately not a runtime assertion over `process.env`. That
 * would reject every ambient variable on the host — a developer's shell, the CI
 * runner, the container platform — none of which is this service's configuration.
 * The property worth enforcing is that every variable the *code* reads is
 * declared, and that is a question about the source, not the environment.
 */
export const DIRECT_ENV_READS_ALLOWED: ReadonlySet<string> = new Set([
  // `S3PrivateObjectStorage` builds its `S3Client` in a field initialiser, which
  // runs during instantiation — before any method can receive `ConfigService`.
  // The keys are deliberately never placed on the validated config object, so
  // they cannot appear in a log line or a `/health` payload.
  'PROVIDER_DOCUMENT_S3_ACCESS_KEY',
  'PROVIDER_DOCUMENT_S3_SECRET_KEY',
  // The integration suite's own database. Not runtime configuration: it exists
  // only so the specs can point at the disposable database they TRUNCATE, and
  // `assertIsolatedTestDatabase` refuses anything that is not loopback:55432.
  'TEST_DATABASE_URL',
]);

function validateAiConfiguration(config: EnvironmentVariables): void {
  if (
    config.AI_ENABLED === BooleanString.True &&
    config.AI_PROVIDER === AiProviderName.Disabled
  ) {
    throw new Error('AI_ENABLED requires a supported AI_PROVIDER');
  }
  if (
    config.NODE_ENV === Environment.Production &&
    config.AI_PROVIDER === AiProviderName.Fake
  ) {
    throw new Error('AI_PROVIDER=fake is prohibited in production');
  }
  if (config.AI_PROVIDER === AiProviderName.HuggingFace && !config.HF_TOKEN) {
    throw new Error('AI_PROVIDER=huggingface requires HF_TOKEN');
  }
  const modalityEnabled =
    config.AI_VOICE_ENABLED === BooleanString.True ||
    config.AI_VISION_ENABLED === BooleanString.True;
  if (
    modalityEnabled &&
    (config.AI_ENABLED !== BooleanString.True ||
      config.AI_PROVIDER === AiProviderName.Disabled)
  ) {
    throw new Error(
      'AI_VOICE_ENABLED / AI_VISION_ENABLED require AI_ENABLED=true and a non-disabled AI_PROVIDER',
    );
  }
}

function validatePushConfiguration(config: EnvironmentVariables): void {
  if (
    config.PUSH_PROVIDER === PushProviderName.Disabled ||
    config.PUSH_PROVIDER === undefined
  ) {
    return;
  }
  if (
    config.NODE_ENV === Environment.Production &&
    config.PUSH_PROVIDER === PushProviderName.Fake
  ) {
    throw new Error('PUSH_PROVIDER=fake is prohibited in production');
  }
  if (config.PUSH_PROVIDER === PushProviderName.Fcm) {
    if (!config.FCM_CREDENTIALS_FILE) {
      throw new Error(
        'PUSH_PROVIDER=fcm requires FCM_CREDENTIALS_FILE pointing at an untracked service-account JSON',
      );
    }
    return;
  }
  // The fake provider is meaningful only outside production, which the
  // earlier check already enforces.
}

function validatePaymentConfiguration(config: EnvironmentVariables): void {
  if (config.PAYMENT_PROVIDER === PaymentProviderName.Fake) {
    if (config.NODE_ENV === Environment.Production) {
      throw new Error('PAYMENT_PROVIDER=fake is prohibited in production');
    }
    return;
  }
  if (config.PAYMENT_PROVIDER === PaymentProviderName.Razorpay) {
    const missing = (
      [
        'RAZORPAY_KEY_ID',
        'RAZORPAY_KEY_SECRET',
        'RAZORPAY_WEBHOOK_SECRET',
      ] as const
    ).filter((name) => !config[name]);
    if (missing.length > 0) {
      throw new Error(
        `PAYMENT_PROVIDER=razorpay requires ${missing.join(', ')}`,
      );
    }
    return;
  }
  throw new Error('PAYMENT_PROVIDER must be one of: fake, razorpay');
}

function validateLocalOtpBypass(config: EnvironmentVariables): void {
  if (
    config.LOCAL_OTP_BYPASS_ENABLED === BooleanString.True &&
    config.NODE_ENV !== Environment.Development
  ) {
    throw new Error(
      'LOCAL_OTP_BYPASS_ENABLED may be enabled only in development',
    );
  }
}

function validateWebOrigins(config: EnvironmentVariables): void {
  validateOriginList(config, config.WEB_ALLOWED_ORIGINS, 'WEB_ALLOWED_ORIGINS');
  validateOriginList(
    config,
    config.EVIDENCE_ALLOWED_ORIGINS,
    'EVIDENCE_ALLOWED_ORIGINS',
  );
}

function validateObjectStorageConfiguration(
  config: EnvironmentVariables,
): void {
  validateObjectStorageEndpoint(config);
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

/**
 * The S3 endpoint that stores provider identity documents.
 *
 * This is operator-supplied rather than attacker-supplied, so it is not an
 * SSRF vector in the usual sense. The reason to pin it down is confidentiality:
 * these are government IDs and selfies, and a cleartext endpoint would put
 * them on the wire in the clear to whatever answered. HTTPS is therefore
 * required in production, and cleartext is permitted only to a loopback
 * address outside production, which is the local MinIO.
 */
function validateObjectStorageEndpoint(config: EnvironmentVariables): void {
  const value = config.PROVIDER_DOCUMENT_S3_ENDPOINT;
  if (!value) return;
  let endpoint: URL;
  try {
    endpoint = new URL(value.trim());
  } catch {
    throw new Error('PROVIDER_DOCUMENT_S3_ENDPOINT must be a valid URL');
  }
  const localDevelopment =
    config.NODE_ENV !== Environment.Production &&
    endpoint.protocol === 'http:' &&
    ['localhost', '127.0.0.1', '::1'].includes(endpoint.hostname);
  if (
    (endpoint.protocol !== 'https:' && !localDevelopment) ||
    endpoint.username ||
    endpoint.password
  ) {
    throw new Error(
      'PROVIDER_DOCUMENT_S3_ENDPOINT must use HTTPS (loopback HTTP is allowed outside production)',
    );
  }
}
