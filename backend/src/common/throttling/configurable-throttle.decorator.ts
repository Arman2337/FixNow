import { SetMetadata } from '@nestjs/common';

/**
 * Metadata key naming the two configuration entries a route's throttle is
 * resolved from.
 *
 * The reason this exists rather than a plain `@Throttle` with larger numbers is
 * that `@Throttle`'s arguments are evaluated when the controller module is
 * imported — before Nest has built the injector and long before `ConfigService`
 * exists. Anything that must come from the environment therefore cannot be
 * written inline in the decorator; it has to be resolved at request time by
 * `ConfigurableThrottleGuard`, which reads this metadata and looks the keys up.
 */
export const CONFIGURABLE_THROTTLE_KEY = 'fixnow.throttle.configurable';

export interface ConfigurableThrottleOptions {
  /** A validated `EnvironmentVariables` key holding the request allowance. */
  limitKey: string;
  /**
   * A validated `EnvironmentVariables` key holding the window length, in
   * milliseconds. Named `*_TTL_MS` because the value is a duration and
   * `@nestjs/throttler` reads `ttl` in milliseconds; a bare `TTL` would be
   * indistinguishable from a seconds value at the call site.
   */
  ttlKey: string;
}

/**
 * Marks a route as throttled by values read from `ConfigService` at request
 * time, rather than by the compile-time constants `@Throttle` requires.
 *
 * Both keys are named rather than resolved here on purpose: this decorator runs
 * during import, so there is no `ConfigService` to ask. The lookup, the bounds
 * check and the fallback all happen in the guard.
 */
export const ConfigurableThrottle = (options: ConfigurableThrottleOptions) =>
  SetMetadata(CONFIGURABLE_THROTTLE_KEY, options);
