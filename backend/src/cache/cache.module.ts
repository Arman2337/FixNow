import {
  Injectable,
  Logger,
  Module,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { CacheModule } from '@nestjs/cache-manager';
import { ConfigService } from '@nestjs/config';
import { connect } from 'net';
import { ReadinessState } from '../health/readiness-state.service';

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

/**
 * The stable key for Redis in the readiness state. Paired with a human-readable
 * detail, so recovery matches on the key rather than on an error message whose
 * wording changes between a refusal and a timeout.
 */
const REDIS_DEPENDENCY_KEY = 'cache.redis';

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

/**
 * BUG-012, second half: watch Redis after boot.
 *
 * The factory above refuses to boot rather than degrade, which closes the case
 * of Redis being unreachable *at startup*. It does nothing about Redis dying
 * afterwards - and that is the case that actually bites, because it is silent.
 *
 * Across replicas, per-process fallback is not a performance problem, it is a
 * privacy one: `invalidateBooking` on cancellation only clears the local
 * instance, so location and consent outlive a cancelled booking everywhere else.
 * Live tracking breaks on most replicas with nothing reporting it, and the
 * customer sees a map that stopped updating rather than an error.
 *
 * So the store is probed on an interval. A failure takes this instance out of
 * the load balancer's rotation - it stops taking new bookings rather than
 * accepting work it cannot track - and recovery puts it back. The TCP probe is
 * deliberately the same one used at boot: it answers "is anything listening",
 * which is the question, without needing a client handle from a factory this
 * module does not own.
 */
@Injectable()
export class RedisAvailabilityWatch implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  private lastState: boolean | null = null;
  private readonly logger = new Logger(RedisAvailabilityWatch.name);

  constructor(
    private readonly config: ConfigService,
    private readonly readiness: ReadinessState,
  ) {}

  /**
   * Whether this instance is obliged to care about Redis.
   *
   * Outside production the in-memory fallback is allowed, so a refused probe is
   * a local annoyance and not a reason to take a developer's instance out of a
   * load balancer that does not exist. Checked in `probeOnce` rather than only
   * in `onModuleInit`, so the answer does not depend on which entry point was
   * used - two places answering the same question is how they disagree.
   */
  private get isWatched(): boolean {
    return (
      this.config.get<string>('NODE_ENV') === 'production' &&
      !!this.config.get<string>('REDIS_URL')
    );
  }

  onModuleInit(): void {
    if (!this.isWatched) return;
    const intervalMs = positiveEnv('REDIS_HEALTH_INTERVAL_MS', 10_000);
    this.timer = setInterval(
      () => {
        void this.probeOnce();
      },
      Math.max(intervalMs, 1_000),
    );
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /** One probe. Public so the interval and a test drive the same code. */
  async probeOnce(
    url = this.config.get<string>('REDIS_URL'),
  ): Promise<boolean> {
    if (!url || !this.isWatched) return true;
    let reachable = false;
    try {
      await probeTcp(url);
      reachable = true;
    } catch (error) {
      reachable = false;
      const reason = error instanceof Error ? error.message : String(error);
      this.readiness.reportDependencyFailure(REDIS_DEPENDENCY_KEY, reason);
    }
    if (reachable) {
      this.readiness.reportDependencyRecovered(REDIS_DEPENDENCY_KEY);
    }
    if (this.lastState !== reachable) {
      this.lastState = reachable;
      if (reachable) {
        this.logger.log('Redis is reachable; this instance is taking traffic.');
      } else {
        this.logger.error(
          'Redis is unreachable; this instance is out of rotation. Live ' +
            'tracking and cross-replica invalidation cannot work, so it must ' +
            'not accept new bookings.',
        );
      }
    }
    return reachable;
  }
}

function positiveEnv(key: string, fallback: number): number {
  const raw = process.env[key]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : fallback;
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
  providers: [RedisAvailabilityWatch],
})
export class RedisCacheModule {}
