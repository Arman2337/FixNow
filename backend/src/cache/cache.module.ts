import { Module } from '@nestjs/common';
import { CacheModule } from '@nestjs/cache-manager';
import { ConfigService } from '@nestjs/config';

@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => {
        // We will mock cache-manager-redis-yet in our tests until the dependencies are fully installed.
        // For graceful degradation, if Redis is down, it will retry and cache gets/sets will safely timeout.
        const url = configService.get<string>('REDIS_URL');
        let store;
        try {
          const { redisStore } = await import('cache-manager-redis-yet');
          store = await redisStore({
            url,
            socket: {
              reconnectStrategy: (retries: number) =>
                Math.min(retries * 50, 2000),
              connectTimeout: 5000,
            },
          });
        } catch {
          // Fallback if module is missing or connection fails synchronously
          store = 'memory';
        }

        return {
          store,
          ttl: 60 * 1000, // Default TTL 60 seconds
        };
      },
    }),
  ],
})
export class RedisCacheModule {}
