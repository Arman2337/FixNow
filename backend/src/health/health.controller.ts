import {
  Controller,
  Get,
  Req,
  Res,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';
import type { Response } from 'express';
import {
  Public,
  RequirePermission,
} from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { assertNoResourceToProve } from '../common/authorization/resource-ownership';
import { ReadinessState } from './readiness-state.service';
import { SystemHealthService } from './system-health.service';
import { renderHealthDashboard } from './health-dashboard';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private readonly readiness: ReadinessState,
    private readonly systemHealth: SystemHealthService,
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

  /**
   * The rendered health dashboard: status, uptime, memory, dependency latency,
   * environment and recent metrics, with an auto-refresh toggle.
   *
   * Admin-gated, unlike the three probes above it. Those are safe to publish
   * because they say almost nothing: liveness is a bare `ok`, and readiness
   * reports dependency state that the metrics endpoint already exposes as
   * route templates and status classes. This page adds uptime, heap usage,
   * `NODE_ENV`, the listening port and `TRUST_PROXY_HOPS` — and that last one
   * is the reason the gate is here rather than a `@Public()`. It tells a caller
   * how many hops to forge in `X-Forwarded-For` before Express stops trusting
   * it, which is precisely the input SEC-006's rate-limit boundary rests on.
   *
   * Rendered rather than returned as JSON because the request was for something
   * an operator can read without a client. The facts themselves are collected
   * by `SystemHealthService`, which has no opinion about markup.
   */
  @RequirePermission(PERMISSIONS.adminSystemHealthRead)
  @Get('dashboard')
  async dashboard(
    @Req() req: AuthorizedRequest,
    @Res() response: Response,
  ): Promise<void> {
    // SEC-002: there is no caller-named resource here. The page describes the
    // instance, and the principal's job is only to prove they may read it — so
    // the obligation is discharged explicitly rather than left outstanding for
    // the interceptor to fail closed on.
    assertNoResourceToProve(req.authorizationPrincipal);

    const report = await this.systemHealth.collect();

    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    // Same reasoning as the metrics endpoint: a cached health page is worse than
    // no health page, because a stale reading is indistinguishable from a live
    // one and an operator would act on it.
    response.setHeader('Cache-Control', 'no-store');
    // This page is the one response in the service that is HTML, so the global
    // `default-src 'none'` CSP set by `SecurityHeadersMiddleware` would blank
    // it. That directive is correct for the JSON API and wrong here, so it is
    // replaced for this response only — narrowly, and without relaxing the
    // directives that actually matter (`frame-ancestors 'none'` stops clickjacking
    // an authenticated admin session, and stays).
    response.setHeader(
      'Content-Security-Policy',
      [
        "default-src 'none'",
        // Inline style and script, which is why this page carries its own
        // stylesheet. `'unsafe-inline'` is the concession made for a self-
        // contained page; it is scoped to this response and to this route, and
        // no other route inherits it.
        "style-src 'unsafe-inline'",
        "script-src 'unsafe-inline'",
        "img-src 'self' data:",
        "connect-src 'self'",
        "frame-ancestors 'none'",
        "base-uri 'none'",
        "form-action 'none'",
      ].join('; '),
    );
    response.status(200).send(renderHealthDashboard(report));
  }
}
