import { Test, TestingModule } from '@nestjs/testing';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { createServer, Server } from 'net';
import { RedisCacheModule } from './cache.module';

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
