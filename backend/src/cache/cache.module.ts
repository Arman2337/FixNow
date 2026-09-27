import { Logger, Module } from '@nestjs/common';
import { CacheModule } from '@nestjs/cache-manager';
import { ConfigService } from '@nestjs/config';
import { connect } from 'net';

/**
 * BUG-012. The store factory used to catch any failure and substitute
 * `store = 'memory'` with no log, no metric and no readiness failure, while
 * `REDIS_URL` is a *required* environment variable - so the configuration said
 * Redis was mandatory and the runtime said it was optional.
 *
 * Across replicas that is not a performance problem, it is a privacy problem.
 * `invalidateBooking` on cancellation only clears the local instance, so
 * location and consent state survive a cancelled booking on every other
 * replica, silently. Live tracking is broken on most replicas with nothing
 * anywhere reporting it.
 *
 * So: in production an unusable Redis now fails the boot rather than quietly
 * degrading. Outside production the in-memory fallback is kept, but it is now
 * loud.
 */

const CONNECT_PROBE_TIMEOUT_MS = 2_000;

/**
 * `redisStore()` does not necessarily connect eagerly, so an unreachable Redis
 * can produce a store object that looks fine and then silently misses forever.
 * A short TCP probe makes "configured but unreachable" visible at boot.
 */
function probeTcp(url: string | undefined): Promise<void> {
  return new Promise((resolve, reject) => {
    let parsed: URL;
    try {
      parsed = new URL(url ?? '');
    } catch {
      reject(new Error('REDIS_URL is not a valid URL'));
      return;
    }
    const port = Number(parsed.port || 6379);
    const socket = connect({ host: parsed.hostname, port });
    const finish = (error?: Error) => {
      socket.removeAllListeners();
      socket.destroy();
      if (error) reject(error);
      else resolve();
    };
    socket.setTimeout(CONNECT_PROBE_TIMEOUT_MS, () =>
      finish(new Error(`timed out connecting to ${parsed.hostname}:${port}`)),
    );
    socket.once('connect', () => finish());
    socket.once('error', (error: Error) => finish(error));
  });
}

@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => {
        const logger = new Logger(RedisCacheModule.name);
        const url = configService.get<string>('REDIS_URL');
        const isProduction =
          configService.get<string>('NODE_ENV') === 'production';

        try {
          if (!url) {
            throw new Error('REDIS_URL is not set');
          }
          // Fail fast rather than booting into a store that never connects.
          await probeTcp(url);

          const { redisStore } = await import('cache-manager-redis-yet');
          const store = await redisStore({
            url,
            socket: {
              reconnectStrategy: (retries: number) =>
                Math.min(retries * 50, 2000),
              connectTimeout: 5000,
            },
          });

          return {
            store,
            ttl: 60 * 1000,
          };
        } catch (error) {
          const reason = error instanceof Error ? error.message : String(error);

          if (isProduction) {
            // Refusing to boot is the point. A degraded cache in production
            // means location and consent outlive a cancelled booking.
            throw new Error(
              `Redis is required in production but is unusable: ${reason}`,
            );
          }

          logger.warn(
            `Falling back to an in-memory cache (${reason}). ` +
              `Live tracking and cross-replica invalidation will not work. ` +
              `This fallback is disabled in production.`,
          );
          return {
            store: 'memory',
            ttl: 60 * 1000,
          };
        }
      },
    }),
  ],
})
export class RedisCacheModule {}
