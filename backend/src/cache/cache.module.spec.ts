import { Test, TestingModule } from '@nestjs/testing';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { createServer, Server } from 'net';
import { RedisAvailabilityWatch, RedisCacheModule } from './cache.module';
import { HealthModule } from '../health/health.module';
import { ReadinessState } from '../health/readiness-state.service';

/**
 * BUG-012: the store factory used to fall back to an in-memory cache on any
 * failure, silently, including in production.
 */
describe('RedisCacheModule fallback policy', () => {
  let listener: Server;
  let port: number;

  beforeAll(async () => {
    listener = createServer();
    await new Promise<void>((resolve) =>
      listener.listen(0, '127.0.0.1', resolve),
    );
    const address = listener.address();
    port = typeof address === 'object' && address ? address.port : 0;
  });

  afterAll(async () => {
    await new Promise<void>((resolve) => listener.close(() => resolve()));
  });

  const build = async (env: Record<string, string>): Promise<TestingModule> =>
    Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          ignoreEnvVars: true,
          load: [() => env],
        }),
        // `HealthModule` is `@Global`, so in the application its
        // `ReadinessState` is visible to the cache module without an explicit
        // import. The test imports it for the same reason, and uses the real
        // provider rather than a mock - the integration between the watch and
        // the readiness state is the thing under test.
        HealthModule,
        RedisCacheModule,
      ],
    }).compile();

  it('boots when Redis is reachable', async () => {
    const module = await build({
      REDIS_URL: `redis://127.0.0.1:${port}`,
      NODE_ENV: 'test',
    });
    expect(module).toBeDefined();
    await module.close();
  });

  it('refuses to boot in production when Redis is unreachable', async () => {
    // Port 1 is reserved and nothing listens on it.
    await expect(
      build({ REDIS_URL: 'redis://127.0.0.1:1', NODE_ENV: 'production' }),
    ).rejects.toThrow(/Redis is required in production/);
  });

  it('refuses to boot in production when REDIS_URL is missing', async () => {
    await expect(build({ NODE_ENV: 'production' })).rejects.toThrow(
      /Redis is required in production/,
    );
  });

  it('still falls back outside production, so local work is not blocked', async () => {
    const module = await build({
      REDIS_URL: 'redis://127.0.0.1:1',
      NODE_ENV: 'development',
    });
    expect(module).toBeDefined();
    await module.close();
  });

  it('uses the configured URL for the probe', async () => {
    const module = await build({
      REDIS_URL: `redis://127.0.0.1:${port}`,
      NODE_ENV: 'test',
    });
    // A reachable endpoint means the probe resolved and did not reject.
    expect(module.get(ConfigService).get<string>('REDIS_URL')).toBe(
      `redis://127.0.0.1:${port}`,
    );
    await module.close();
  });
});

/**
 * BUG-012, second half: the case the boot-time guard cannot cover.
 *
 * Refusing to start is the right answer when Redis is unreachable at boot. It
 * says nothing about Redis dying an hour later, and that is the case that
 * actually bites, because it is silent: with a per-process fallback, a
 * provider's WebSocket lands on replica A, their presence writes to A's memory,
 * and a location update routed to B finds no presence key and returns 403. The
 * customer sees a map that stopped updating rather than an error, and location
 * and consent outlive a cancelled booking on every other replica.
 *
 * So the instance leaves the load balancer's rotation instead.
 */
describe('RedisAvailabilityWatch', () => {
  let listener: Server;
  let port: number;
  let readiness: ReadinessState;

  beforeAll(async () => {
    listener = createServer();
    await new Promise<void>((resolve) =>
      listener.listen(0, '127.0.0.1', resolve),
    );
    const address = listener.address();
    port = typeof address === 'object' && address ? address.port : 0;
  });

  afterAll(async () => {
    await new Promise<void>((resolve) => listener.close(() => resolve()));
  });

  beforeEach(() => {
    readiness = new ReadinessState();
  });

  const build = (env: Record<string, string>) =>
    Test.createTestingModule({
      providers: [
        RedisAvailabilityWatch,
        { provide: ReadinessState, useValue: readiness },
        {
          provide: ConfigService,
          useValue: { get: (key: string) => env[key] },
        },
      ],
    }).compile();

  it('keeps the instance ready while Redis answers', async () => {
    const module = await build({
      REDIS_URL: `redis://127.0.0.1:${port}`,
      NODE_ENV: 'production',
    });
    const watch = module.get(RedisAvailabilityWatch);

    await expect(watch.probeOnce()).resolves.toBe(true);
    expect(readiness.isReady).toBe(true);
    await module.close();
  });

  it('takes the instance out of rotation when Redis stops answering', async () => {
    const module = await build({
      REDIS_URL: `redis://127.0.0.1:${port}`,
      NODE_ENV: 'production',
    });
    const watch = module.get(RedisAvailabilityWatch);

    await watch.probeOnce();
    expect(readiness.isReady).toBe(true);

    // The listener is closed, so the same URL now refuses connections.
    await new Promise<void>((resolve) => listener.close(() => resolve()));

    await expect(watch.probeOnce()).resolves.toBe(false);
    expect(readiness.isReady).toBe(false);
    expect(readiness.state.reason).toContain('cache.redis');
    await module.close();
  });

  it('does not watch outside production, where the fallback is allowed', async () => {
    const module = await build({
      REDIS_URL: 'redis://127.0.0.1:1',
      NODE_ENV: 'development',
    });
    const watch = module.get(RedisAvailabilityWatch);
    watch.onModuleInit();
    // A refused probe in development is a local annoyance, not a reason to take
    // a developer's instance out of a load balancer that does not exist.
    await expect(watch.probeOnce()).resolves.toBe(true);
    expect(readiness.isReady).toBe(true);
    await module.close();
  });
});
