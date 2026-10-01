import type { INestApplication } from '@nestjs/common';
import type { ReadinessState } from '../health/readiness-state.service';

/**
 * The slice of the pino-backed logger this module needs. Structural rather than
 * the concrete service type, so a test can pass three jest mocks and so the
 * module does not depend on `nestjs-pino` at all.
 */
export interface ShutdownLogger {
  log(message: string, ...rest: unknown[]): void;
  warn(message: string, ...rest: unknown[]): void;
  error(message: string, ...rest: unknown[]): void;
}

export interface GracefulShutdownDeps {
  app: INestApplication;
  readiness: ReadinessState;
  logger: ShutdownLogger;
  timeoutMs: number;
}

/**
 * OPS-002. A deploy should not cut off a request that is already running.
 *
 * The three `onModuleDestroy` handlers in this codebase - the emergency
 * scanner's interval, the reminder scanner's, and the realtime gateway's
 * heartbeat plus every open socket - were never invoked, because Nest only calls
 * them in response to its own shutdown signals and `enableShutdownHooks` was
 * never enabled. So a deploy SIGTERM'd the process and Node killed it wherever it
 * happened to be: mid push fan-out, mid database query, with sockets dropped
 * without a close frame so every client saw an abnormal closure.
 *
 * The order below is the whole design:
 *
 *   1. Readiness starts failing. The load balancer stops sending *new* requests.
 *      Without this the drain races live traffic, and the drain is what drops it.
 *   2. `app.close()` stops accepting and lets in-flight requests finish, then
 *      runs `onModuleDestroy` (clearing the timers, closing the sockets with a
 *      proper close code), and finally destroys the data source.
 *   3. A deadline bounds the whole thing, because an unbounded drain is a deploy
 *      that hangs until the platform hard-kills it - which is the abrupt exit we
 *      were trying to avoid, plus an operator watching.
 *
 * Extracted from `main.ts` so the sequence is testable without booting an
 * application.
 */
export function runGracefulShutdown(deps: GracefulShutdownDeps): void {
  const { app, readiness, logger, timeoutMs } = deps;
  let draining = false;

  const drain = async (signal: NodeJS.Signals): Promise<void> => {
    // Idempotent. A platform that sends SIGTERM and then SIGINT a moment later
    // must not start a second drain, or the deadline resets and the first
    // drain's work is abandoned.
    if (draining) return;
    draining = true;
    readiness.beginDraining(signal);

    const deadline = setTimeout(() => {
      logger.warn(
        `Graceful shutdown exceeded ${timeoutMs}ms; exiting anyway. ` +
          `In-flight requests were cut off rather than completed.`,
      );
      process.exit(1);
    }, timeoutMs);
    // Unref'd so a pending deadline cannot itself hold the process open - the
    // timer is a backstop, not a reason to stay alive.
    deadline.unref();

    try {
      await app.close();
      logger.log(`Graceful shutdown complete (${signal}).`);
      process.exit(0);
    } catch (error) {
      logger.error(
        `Graceful shutdown failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      process.exit(1);
    } finally {
      clearTimeout(deadline);
    }
  };

  process.once('SIGTERM', () => void drain('SIGTERM'));
  process.once('SIGINT', () => void drain('SIGINT'));
}
