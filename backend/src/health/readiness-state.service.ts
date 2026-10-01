import { Injectable, Logger } from '@nestjs/common';

/**
 * Whether this instance should still be sent traffic.
 *
 * OPS-002 and BUG-012 together. Two different failures, one signal:
 *
 * - A deploy. The process is about to stop, and a load balancer that has not
 *   been told will keep sending requests into a process that is closing. Those
 *   requests are cut off mid-flight, which is the opposite of a graceful
 *   shutdown.
 * - An unusable Redis. `REDIS_URL` is a required variable and the cache module
 *   already refuses to boot in production rather than degrading to per-process
 *   memory - but a Redis that dies *after* boot is a different case, and the
 *   only honest response is to stop taking work rather than serve it with
 *   location and consent state that is silently local to this process.
 *
 * So the readiness probe is not a static "the database answers a ping". It asks
 * the one question that matters during a drain or a degradation: should this
 * instance receive new work?
 */
@Injectable()
export class ReadinessState {
  private draining = false;
  /**
   * Which dependency is unavailable, and why. Keyed separately from the detail
   * because the detail carries a variable error message - `ECONNREFUSED` one
   * second and a timeout the next - and matching recovery on the full string
   * means the instance never leaves the degraded state, because the recovery
   * call can never reproduce the failure's exact wording.
   */
  private dependency: { key: string; detail: string } | null = null;
  private readonly logger = new Logger(ReadinessState.name);

  /**
   * Starts the drain.
   *
   * Idempotent, and the first signal wins: a second SIGTERM during a slow drain
   * must not reset the reason and confuse the log, because the operator reading
   * it is trying to work out why the deploy took thirty seconds.
   */
  beginDraining(signal: NodeJS.Signals): void {
    if (this.draining) return;
    this.draining = true;
    this.logger.warn(
      `Draining for ${signal}: readiness now reports not-ready so the load ` +
        `balancer stops sending new requests. In-flight requests will finish.`,
    );
  }

  /**
   * Records that something this instance needs is unavailable.
   *
   * `key` identifies the dependency and must be stable; `detail` is for humans.
   * Kept separate from `beginDraining` because the two have different causes and
   * an operator needs to tell them apart: a drain is planned, a dependency
   * failure is not, and only one of them ends when the deploy finishes.
   */
  reportDependencyFailure(key: string, detail: string): void {
    if (this.dependency?.key === key) return;
    this.dependency = { key, detail };
    this.logger.error(`Readiness degraded: ${key} - ${detail}`);
  }

  reportDependencyRecovered(key: string): void {
    if (this.dependency?.key !== key) return;
    this.dependency = null;
    this.logger.log(`Readiness recovered: ${key}`);
  }

  get isReady(): boolean {
    return !this.draining && this.dependency === null;
  }

  get state(): {
    ready: boolean;
    draining: boolean;
    reason: string | null;
  } {
    return {
      ready: this.isReady,
      draining: this.draining,
      reason: this.dependency
        ? `${this.dependency.key}: ${this.dependency.detail}`
        : null,
    };
  }
}

/**
 * How long a drain may take before the process exits anyway.
 *
 * Bounded because an unbounded graceful shutdown is a deploy that hangs until
 * the platform kills it - which is a hard kill with all the abruptness a hard
 * kill has, plus an operator waiting. Slightly under the common 30-second
 * platform SIGTERM grace period, so the timeout fires before the platform's.
 */
export const SHUTDOWN_TIMEOUT_MS = 25_000;
