import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  Optional,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import {
  DataSource,
  EntityManager,
  In,
  IsNull,
  QueryFailedError,
  QueryRunner,
} from 'typeorm';
import { OutboxMessage, OutboxMessageKind } from './outbox-message.entity';
import { runBounded } from '../common/run-bounded';
import { ObservabilityService } from '../observability/observability.service';

/**
 * FN-082. Transactional outbox: write the intent inside the transaction, drain
 * it outside.
 *
 * Why not a fire-and-forget `void promise()`: a pod recycled mid-dispatch loses
 * the notification, which is exactly the moment the notification matters. Why
 * not "send after commit, then await it": that is BUG-005, and it puts up to six
 * seconds of third-party latency into an HTTP response.
 *
 * The enqueue side takes an `EntityManager` deliberately. An outbox row written
 * on a different connection than the state change it describes reintroduces the
 * original problem in a new shape: the state can commit while the row does not.
 */
@Injectable()
export class OutboxService {
  private readonly logger = new Logger(OutboxService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    // `ObservabilityModule` is `@Global()`, so the running application always
    // injects this. Optional so a unit test can build the service without a
    // metrics graph — the backlog gauge is observability, not behaviour, and its
    // absence must never change what a drain does.
    private readonly observability?: ObservabilityService,
  ) {}

  /**
   * Rows waiting to be drained: not yet processed, and not claimed by a worker
   * that is still working on them.
   *
   * Claims are excluded deliberately. A row a worker currently holds is being
   * handled, and counting it would make the gauge rise during a healthy slow
   * drain and fall afterwards — a number that moves for the wrong reason is worse
   * than no number at all.
   */
  async pendingBacklog(): Promise<number> {
    return this.dataSource.getRepository(OutboxMessage).count({
      where: { processedAt: IsNull(), claimedAt: IsNull() },
    });
  }

  /**
   * Records a message inside the caller's transaction.
   *
   * Returns `false` when the dedupe key already exists. That is a success, not
   * an error: re-running the same fan-out - a retried request, a re-raised
   * emergency - must not produce a second offer. This is what closes BUG-022,
   * where the ordinary and emergency paths derived different dedupe keys for the
   * same underlying offer and pushed it twice.
   */
  async enqueue(
    manager: EntityManager,
    message: {
      kind: OutboxMessageKind;
      dedupeKey: string;
      payload: Record<string, unknown>;
      availableAt?: Date;
    },
  ): Promise<boolean> {
    try {
      const repository = manager.getRepository(OutboxMessage);
      await repository.insert({
        kind: message.kind,
        dedupeKey: message.dedupeKey,
        // Cast rather than spread: `insert` types its argument as a deep partial,
        // and a `Record<string, unknown>` payload is not assignable to it without
        // one. The value is a jsonb column, so the shape is whatever the
        // handler for this kind expects.
        payload: message.payload as never,
        availableAt: message.availableAt ?? new Date(),
        attempts: 0,
        claimedAt: null,
        processedAt: null,
        lastError: null,
      });
      return true;
    } catch (error) {
      if (isUniqueViolation(error)) return false;
      throw error;
    }
  }

  /**
   * Claims a batch for one worker.
   *
   * `FOR UPDATE SKIP LOCKED` is the whole concurrency story. Two replicas
   * running the same drain never contend: each statement takes the rows it can
   * get and walks past the ones another worker already holds, so fan-out is
   * distributed rather than duplicated. Without it every replica would claim the
   * same oldest rows, and the `dedupe_key` index would be doing the deduplication
   * work the row lock should have done.
   *
   * Rows are NOT marked processed here. They are returned to the caller, which
   * performs the side effect and then marks them, so a crash mid-handler leaves
   * them claimable again once `CLAIM_TIMEOUT_MS` has passed.
   */
  async claimBatch(limit: number): Promise<OutboxMessage[]> {
    const runner = this.dataSource.createQueryRunner();
    await runner.connect();
    await runner.startTransaction();
    try {
      const rows = await runner.manager
        .getRepository(OutboxMessage)
        .createQueryBuilder('message')
        .where('message.processed_at IS NULL')
        .andWhere('message.available_at <= CURRENT_TIMESTAMP')
        // A row claimed by a worker that then died is recovered rather than
        // stranded. Without this bound one pod restart silently stops every
        // notification on the platform.
        .andWhere(
          '(message.claimed_at IS NULL OR message.claimed_at < :staleBefore)',
          { staleBefore: new Date(Date.now() - CLAIM_TIMEOUT_MS) },
        )
        .orderBy('message.available_at', 'ASC')
        .addOrderBy('message.id', 'ASC')
        .limit(limit)
        .setLock('pessimistic_write')
        .setOnLocked('skip_locked')
        .getMany();

      if (rows.length > 0) {
        await markClaimed(
          runner,
          rows.map((row) => row.id),
        );
      }
      await runner.commitTransaction();
      return rows;
    } catch (error) {
      await safeRollback(runner);
      throw error;
    } finally {
      await runner.release();
    }
  }

  async markProcessed(ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    await this.dataSource
      .getRepository(OutboxMessage)
      .update(
        { id: In(ids) },
        { processedAt: new Date(), claimedAt: null, lastError: null },
      );
  }

  /**
   * Releases a failed message for a later attempt, or abandons it once it has
   * burned `MAX_ATTEMPTS`. An undeliverable offer must not block the queue
   * behind it, and the delivery attempts are already recorded by the
   * notification service, so nothing is lost by giving up on the row.
   */
  async release(id: string, error: unknown): Promise<void> {
    const repository = this.dataSource.getRepository(OutboxMessage);
    const message = await repository.findOneBy({ id });
    if (!message) return;
    const detail = describe(error).slice(0, 1000);

    if (message.attempts >= MAX_ATTEMPTS) {
      await repository.update(
        { id },
        { processedAt: new Date(), claimedAt: null, lastError: detail },
      );
      this.logger.warn(
        `Outbox message ${id} (${message.kind}) abandoned after ${message.attempts} attempts`,
      );
      return;
    }
    // Backoff grows with the attempt count and is capped, so a handler failing
    // because a dependency is down does not spin at the drain rate.
    const backoffMs = Math.min(2 ** message.attempts * 1_000, 5 * 60_000);
    await repository.update(
      { id },
      {
        claimedAt: null,
        availableAt: new Date(Date.now() + backoffMs),
        lastError: detail,
      },
    );
  }

  /** Deletes processed rows older than the retention window. */
  async prune(olderThan: Date): Promise<number> {
    const result = await this.dataSource
      .getRepository(OutboxMessage)
      .createQueryBuilder()
      .delete()
      .where('"processed_at" IS NOT NULL')
      .andWhere('"processed_at" < :olderThan', { olderThan })
      .execute();
    return result.affected ?? 0;
  }
}

/**
 * The drain loop. Deliberately a separate provider from {@link OutboxService},
 * so the enqueue path carries no timer, no handler registry and no lifecycle -
 * it is called from inside a transaction and must stay cheap and inert.
 */
@Injectable()
export class OutboxWorker implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  /**
   * BUG-006 in its general form: `setInterval` does not await its callback, so a
   * slow drain overlaps the next one instead of queueing behind it. On one
   * replica that is wasted work; across replicas it is the duplicate fan-out the
   * row lock exists to prevent, and the process survives neither.
   */
  private draining = false;
  private stopped = false;
  private readonly handlers = new Map<OutboxMessageKind, OutboxHandler>();

  private readonly logger = new Logger(OutboxWorker.name);

  constructor(
    private readonly outbox: OutboxService,
    // See `OutboxService`'s note: observability is optional so it can never
    // change what a drain does.
    @Optional()
    private readonly observability?: ObservabilityService,
  ) {}

  register(kind: OutboxMessageKind, handler: OutboxHandler): void {
    this.handlers.set(kind, handler);
  }

  onModuleInit(): void {
    const intervalMs = positiveEnv('OUTBOX_DRAIN_INTERVAL_MS', 1_000);
    this.timer = setInterval(
      () => {
        void this.drainSafely();
      },
      Math.max(intervalMs, 100),
    );
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    // OPS-002. `stopped` prevents a tick already in flight from starting
    // another drain during shutdown, so a deploy finishes the batch it claimed
    // rather than abandoning half a wave.
    this.stopped = true;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /**
   * One drain pass. Public and deterministic so tests can drive it directly
   * instead of waiting on the timer.
   *
   * Every message is accounted for: handled, released for retry, or abandoned.
   * A message that is neither processed nor released would stay claimed until
   * `CLAIM_TIMEOUT_MS`, which is a silent stall of the whole platform - so the
   * failure path is explicit here rather than left to a catch-all.
   */
  async drainOnce(limit = DRAIN_BATCH): Promise<number> {
    const claimed = await this.outbox.claimBatch(limit);
    // Observability. A worker that stops draining is the quietest possible
    // failure in this codebase: enqueueing still succeeds, the state changes
    // still commit, and the only symptom is that customers stop being notified.
    // Publishing the backlog on every pass — including the empty one, which is
    // the case that matters — turns it into a number that stops moving.
    this.observability?.setOutboxBacklog(await this.outbox.pendingBacklog());
    if (claimed.length === 0) return 0;

    const handled: string[] = [];
    const failed: Array<{ id: string; error: unknown }> = [];

    await runBounded(
      claimed.map((message) => async () => {
        try {
          const handler = this.handlers.get(message.kind);
          // No handler is a deployment error, not a transient one. It goes
          // through the same retry budget as any other failure so it surfaces as
          // a warning rather than an infinite loop.
          if (!handler) throw new NoHandlerError(message.kind);
          await handler(message);
          handled.push(message.id);
        } catch (error) {
          // `runBounded` swallows the error, so it is captured here where it can
          // still be attached to the row. A message that is neither processed
          // nor released would stay claimed until `CLAIM_TIMEOUT_MS`, which is a
          // silent stall of the whole platform.
          failed.push({ id: message.id, error });
        }
      }),
      HANDLER_CONCURRENCY,
    );

    for (const failure of failed) {
      await this.outbox.release(failure.id, failure.error);
    }
    await this.outbox.markProcessed(handled);
    return handled.length;
  }

  private async drainSafely(): Promise<void> {
    if (this.draining || this.stopped) return;
    this.draining = true;
    try {
      await this.drainOnce();
    } catch (error) {
      this.logger.error(`Outbox drain failed: ${describe(error)}`);
    } finally {
      this.draining = false;
    }
  }
}

/** A pure side effect. Throwing releases the row for a later attempt. */
export type OutboxHandler = (message: OutboxMessage) => Promise<void> | void;

class NoHandlerError extends Error {
  constructor(kind: string) {
    super(`No outbox handler registered for "${kind}"`);
    this.name = 'NoHandlerError';
  }
}

/**
 * A claimed row whose worker died is recovered after this long. Longer than any
 * realistic single drain pass; short enough that a pod restart does not silence
 * the platform for minutes.
 */
const CLAIM_TIMEOUT_MS = 60_000;

/** Rows claimed per pass. */
const DRAIN_BATCH = 50;

/** Side effects in flight at once, so one slow push cannot serialise the batch. */
const HANDLER_CONCURRENCY = 10;

/** Attempts before a message is abandoned rather than retried. */
const MAX_ATTEMPTS = 5;

async function markClaimed(runner: QueryRunner, ids: string[]): Promise<void> {
  await runner.manager
    .getRepository(OutboxMessage)
    .update(
      { id: In(ids) },
      { claimedAt: new Date(), attempts: () => '"attempts" + 1' },
    );
}

async function safeRollback(runner: QueryRunner): Promise<void> {
  try {
    await runner.rollbackTransaction();
  } catch {
    // The connection is being released regardless.
  }
}

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof QueryFailedError &&
    (error as { driverError?: { code?: string } }).driverError?.code === '23505'
  );
}

function describe(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function positiveEnv(key: string, fallback: number): number {
  const raw = process.env[key]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}
