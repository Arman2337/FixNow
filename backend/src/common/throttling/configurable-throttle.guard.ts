import { Injectable, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import {
  ThrottlerGuard,
  type ThrottlerRequest,
  type ThrottlerStorage,
  type ThrottlerModuleOptions,
  type ThrottlerOptions,
  InjectThrottlerOptions,
  InjectThrottlerStorage,
} from '@nestjs/throttler';
import {
  CONFIGURABLE_THROTTLE_KEY,
  type ConfigurableThrottleOptions,
} from './configurable-throttle.decorator';

/**
 * Lets a route's throttle be read from the environment instead of from the
 * constants `@Throttle` bakes in at import time.
 *
 * A `@Throttle({ default: { limit: 6 } })` is compiled into the controller. That
 * is right for a login form and wrong for anything an operator has to change
 * while the service is running: the six-per-hour on
 * `PUT /provider-profile/me/location` (BUG-016) produced a steady stream of
 * 429s during live testing, and the only way to relieve it was a code change
 * and a redeploy.
 *
 * This guard extends `ThrottlerGuard` rather than replacing it so the storage,
 * the `X-RateLimit-*` headers, `Retry-After`, the tracker function, the key
 * derivation and the thrown `ThrottlerException` are all the library's. The
 * configured route delegates to the inherited `handleRequest`, which is where
 * that logic lives; only the two numbers it is handed differ.
 *
 * It *replaces* the compile-time allowance for the route rather than adding a
 * second bucket, which is what a separately-named throttler would do — a route
 * under two buckets is limited by whichever is stricter, and which one that is
 * changes with configuration rather than with intent.
 *
 * Routes without the metadata are handed straight to `super.canActivate`, so
 * this can be registered globally in place of `ThrottlerGuard` without altering
 * any other route's behaviour.
 */
@Injectable()
export class ConfigurableThrottleGuard extends ThrottlerGuard {
  constructor(
    @InjectThrottlerOptions() options: ThrottlerModuleOptions,
    @InjectThrottlerStorage() storageService: ThrottlerStorage,
    reflector: Reflector,
    private readonly config: ConfigService,
  ) {
    super(options, storageService, reflector);
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const configurable = this.reflector.getAllAndOverride<
      ConfigurableThrottleOptions | undefined
    >(CONFIGURABLE_THROTTLE_KEY, [context.getHandler(), context.getClass()]);

    if (!configurable) return super.canActivate(context);
    if (await this.shouldSkip(context)) return true;

    const limit = this.config.get<number>(configurable.limitKey);
    const ttl = this.config.get<number>(configurable.ttlKey);

    // Both are declared in `EnvironmentVariables` with bounds, so a missing or
    // non-numeric value here means the validator was bypassed rather than that
    // the operator left it out. Failing loudly beats silently falling back to a
    // guess: the number decides whether a legitimate provider is refused.
    if (typeof limit !== 'number' || !Number.isFinite(limit) || limit < 1) {
      throw new Error(
        `${configurable.limitKey} must resolve to a positive number; it currently resolves to ${String(limit)}.`,
      );
    }
    if (typeof ttl !== 'number' || !Number.isFinite(ttl) || ttl < 1) {
      throw new Error(
        `${configurable.ttlKey} must resolve to a positive number of milliseconds; it currently resolves to ${String(ttl)}.`,
      );
    }

    // Reuse the `default` throttler's identity so the storage key and the
    // `X-RateLimit-*` header names stay the ones the rest of the app uses.
    const throttler: ThrottlerOptions =
      this.throttlers.find((candidate) => candidate.name === 'default') ??
      this.throttlers[0];

    // `commonOptions.getTracker` / `generateKey` are typed optional but
    // `ThrottlerGuard.onModuleInit` unconditionally binds both to the guard's
    // own methods, so by the time a request arrives they are always present.
    // Falling back to this guard's implementations keeps the non-null
    // assertion off the assignment: if the library ever stopped binding them,
    // the tracker and key derivation below would still be the stock ones rather
    // than `undefined` reaching `handleRequest`.
    const props: ThrottlerRequest = {
      context,
      limit,
      ttl,
      blockDuration: ttl,
      throttler,
      getTracker:
        throttler.getTracker ??
        this.commonOptions.getTracker ??
        this.getTracker.bind(this),
      generateKey:
        throttler.generateKey ??
        this.commonOptions.generateKey ??
        this.generateKey.bind(this),
    };
    return this.handleRequest(props);
  }
}
