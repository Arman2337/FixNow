/* Route handlers are pulled off the prototype to stand in for `getHandler()`,
 * which is exactly the unbound-method shape this rule warns about — the calls
 * here never re-attach `this`, and there is no object to detach them from. */
/* eslint-disable @typescript-eslint/unbound-method */
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import type { ExecutionContext } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import { ConfigurableThrottleGuard } from './configurable-throttle.guard';
import { ConfigurableThrottle } from './configurable-throttle.decorator';
import type { ConfigurableThrottleOptions } from './configurable-throttle.decorator';
import { ProviderProfileController } from '../../providers/provider-profile.controller';

/**
 * A storage double standing in for the throttler's Redis/in-memory storage.
 *
 * Records the `(key, ttl, limit)` triple of every increment, because that triple
 * IS the behaviour under test: a route's effective allowance is the `limit` and
 * `ttl` handed to storage, and nothing else about the guard is observable from
 * outside it.
 */
function createStorage() {
  const hits = new Map<string, number>();
  return {
    hits,
    increment: jest.fn(
      async (
        key: string,
        _ttl: number,
        limit: number,
      ): Promise<{
        totalHits: number;
        timeToExpire: number;
        isBlocked: boolean;
        timeToBlockExpire: number;
      }> => {
        const totalHits = (hits.get(key) ?? 0) + 1;
        hits.set(key, totalHits);
        return {
          totalHits,
          timeToExpire: 0,
          isBlocked: totalHits > limit,
          timeToBlockExpire: 0,
        };
      },
    ),
  };
}

function contextFor(handler: (...args: never[]) => unknown): ExecutionContext {
  const res = { header: jest.fn() };
  const req = { ip: '203.0.113.9', headers: {} };
  return {
    getHandler: () => handler,
    getClass: () => class {},
    switchToHttp: () => ({ getRequest: () => req, getResponse: () => res }),
  } as unknown as ExecutionContext;
}

async function buildGuard(values: Record<string, number>) {
  const storage = createStorage();
  const reflector = new Reflector();

  // Constructed directly rather than through the testing module: the parent's
  // two injected tokens are opaque symbols from `getOptionsToken()` /
  // `getStorageToken()`, and re-providing them under guessed names produced a
  // DI failure that says nothing about the guard. The options are the same array
  // `app.module.ts` registers — `[{ ttl: 60_000, limit: 60 }]`.
  const guard = new ConfigurableThrottleGuard(
    [{ name: 'default', ttl: 60_000, limit: 60 }],
    storage,
    reflector,
    { get: (key: string) => values[key] } as unknown as ConfigService,
  );

  // `onModuleInit` normally populates these from the module options. Called
  // here rather than hand-assigned so the test drives the same initialisation
  // the application does, instead of a copy of it that can drift.
  await guard.onModuleInit();

  return { guard, storage };
}

describe('ConfigurableThrottleGuard', () => {
  it('is a ThrottlerGuard, so an unmarked route keeps the stock behaviour', async () => {
    const { guard } = await buildGuard({});
    // The regression this class could introduce: reimplementing the throttling
    // and quietly changing headers, storage keys or the thrown exception for
    // every other route in the service.
    expect(guard).toBeInstanceOf(ThrottlerGuard);
  });

  it('applies the configured limit and window to the provider-location route', async () => {
    const { guard, storage } = await buildGuard({
      PROVIDER_LOCATION_THROTTLE_LIMIT: 60,
      PROVIDER_LOCATION_THROTTLE_TTL_MS: 60_000,
    });

    const handler = ProviderProfileController.prototype.updateOwnLocation;
    await guard.canActivate(contextFor(handler));

    expect(storage.increment).toHaveBeenCalledTimes(1);
    expect(storage.increment.mock.calls[0][1]).toBe(60_000);
    expect(storage.increment.mock.calls[0][2]).toBe(60);
  });

  it('takes the limit from configuration rather than from the constant', async () => {
    // The point of BUG-016's change: an operator raises this in a deployment and
    // the 429s stop, with no code change. Before, the value was compiled in.
    const { guard, storage } = await buildGuard({
      PROVIDER_LOCATION_THROTTLE_LIMIT: 500,
      PROVIDER_LOCATION_THROTTLE_TTL_MS: 3_600_000,
    });

    await guard.canActivate(
      contextFor(ProviderProfileController.prototype.updateOwnLocation),
    );

    expect(storage.increment.mock.calls[0][1]).toBe(3_600_000);
    expect(storage.increment.mock.calls[0][2]).toBe(500);
  });

  it('blocks the request that exceeds the configured limit', async () => {
    const { guard } = await buildGuard({
      PROVIDER_LOCATION_THROTTLE_LIMIT: 2,
      PROVIDER_LOCATION_THROTTLE_TTL_MS: 60_000,
    });
    const handler = ProviderProfileController.prototype
      .updateOwnLocation as never;
    const context = () => contextFor(handler);

    await guard.canActivate(context());
    await guard.canActivate(context());
    // The third would be limit+1, and the library's own exception is raised
    // rather than a boolean false, so the client gets a 429 it can act on.
    await expect(guard.canActivate(context())).rejects.toThrow();
  });

  it('leaves an unmarked route on the global 60/min bucket', async () => {
    const { guard, storage } = await buildGuard({
      PROVIDER_LOCATION_THROTTLE_LIMIT: 500,
      PROVIDER_LOCATION_THROTTLE_TTL_MS: 3_600_000,
    });

    // `getOwnProfile` carries no `@ConfigurableThrottle`. Configuring the
    // location route must not move this one.
    await guard.canActivate(
      contextFor(ProviderProfileController.prototype.getOwnProfile),
    );

    expect(storage.increment.mock.calls[0][1]).toBe(60_000);
    expect(storage.increment.mock.calls[0][2]).toBe(60);
  });

  it('refuses to run a configurable route whose limit is not a positive number', async () => {
    // A silently ignored bad value would mean the route is throttled by
    // whatever default happened to apply, which is the failure a config error
    // is supposed to prevent.
    const { guard, storage } = await buildGuard({
      PROVIDER_LOCATION_THROTTLE_LIMIT: Number.NaN,
      PROVIDER_LOCATION_THROTTLE_TTL_MS: 60_000,
    });

    await expect(
      guard.canActivate(
        contextFor(
          ProviderProfileController.prototype.updateOwnLocation as never,
        ),
      ),
    ).rejects.toThrow(/PROVIDER_LOCATION_THROTTLE_LIMIT/);
    expect(storage.increment).not.toHaveBeenCalled();
  });
});

describe('@ConfigurableThrottle metadata', () => {
  it('marks only the location route, not the whole controller', () => {
    const key = 'fixnow.throttle.configurable';
    // `Reflect.getMetadata` is typed `any`; narrowed to the shape the decorator
    // writes so the assertions below are on a typed value.
    const marked = Reflect.getMetadata(
      key,
      ProviderProfileController.prototype.updateOwnLocation,
    ) as ConfigurableThrottleOptions | undefined;
    const unmarked = Reflect.getMetadata(
      key,
      ProviderProfileController.prototype.getOwnProfile,
    ) as ConfigurableThrottleOptions | undefined;

    expect(marked).toEqual({
      limitKey: 'PROVIDER_LOCATION_THROTTLE_LIMIT',
      ttlKey: 'PROVIDER_LOCATION_THROTTLE_TTL_MS',
    });
    // Method-level, not class-level. A class-level marker would silently
    // re-throttle every profile route by an operator tuning one endpoint.
    expect(unmarked).toBeUndefined();
  });

  it('is applied by the decorator it is named after', () => {
    class Probe {
      @ConfigurableThrottle({ limitKey: 'A', ttlKey: 'B' })
      handle(): void {
        /* no-op */
      }
    }
    expect(
      Reflect.getMetadata(
        'fixnow.throttle.configurable',
        Probe.prototype.handle,
      ),
    ).toEqual({ limitKey: 'A', ttlKey: 'B' });
  });
});
