import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';
import { Public } from '../common/authorization/authorization.decorators';
import { ReadinessState } from './readiness-state.service';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private readonly readiness: ReadinessState,
  ) {}

  /**
   * Liveness: is the process itself healthy?
   *
   * Deliberately does not consult the database or the drain state. Liveness
   * answers "should this process be restarted", and a restarting process cannot
   * finish a drain - so a liveness probe that fails during a deploy turns a
   * graceful shutdown into a crash loop, and one that fails because Postgres is
   * briefly unavailable restarts every replica at once, which is how a database
   * blip becomes an outage.
   */
  @Public()
  @Get('liveness')
  @HealthCheck()
  checkLiveness() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Readiness: should this instance receive new requests?
   *
   * This is the probe a load balancer polls, and it is the one that carries the
   * drain signal (OPS-002) and dependency degradation (BUG-012). It throws 503
   * rather than returning a 200 with a flag, because every load balancer in
   * common use keys off the status code - a 200 body that says "not ready" is a
   * body every one of them ignores.
   *
   * The database is checked first, so a genuine outage is reported as a database
   * failure rather than as a generic not-ready.
   */
  @Public()
  @Get('readiness')
  @HealthCheck()
  async checkReadiness() {
    const result = await this.health.check([
      () => this.db.pingCheck('database', { timeout: 3000 }),
    ]);
    if (!this.readiness.isReady) {
      const state = this.readiness.state;
      throw new ServiceUnavailableException({
        status: 'shutting_down',
        ready: false,
        draining: state.draining,
        reason: state.reason,
        database: result,
      });
    }
    return { status: 'ok', ready: true, database: result };
  }

  /**
   * The same answer as a 200, for callers that want to inspect the drain state
   * without treating it as an error - a deploy script checking progress, or an
   * operator asking what the instance thinks of itself.
   */
  @Public()
  @Get('readiness/state')
  state_() {
    return { ...this.readiness.state, timestamp: new Date().toISOString() };
  }
}
