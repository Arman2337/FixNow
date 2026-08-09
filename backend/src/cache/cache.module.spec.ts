import { Test, TestingModule } from '@nestjs/testing';
import { RedisCacheModule } from './cache.module';
import { ConfigModule } from '@nestjs/config';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

describe('RedisCacheModule', () => {
  let module: TestingModule;
  let cache: Cache;

  beforeEach(async () => {
    module = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          ignoreEnvVars: true,
          load: [
            () => ({
              REDIS_URL: 'redis://localhost:6379',
            }),
          ],
        }),
        RedisCacheModule,
      ],
    }).compile();

    cache = module.get<Cache>(CACHE_MANAGER);
  });

  it('should compile the module and provide the cache manager', () => {
    expect(module).toBeDefined();
    expect(cache).toBeDefined();
  });
});
