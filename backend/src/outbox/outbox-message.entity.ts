import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * FN-082. A row written inside the transaction that changed business state,
 * drained afterwards by a worker.
 *
 * The contract is deliberately narrow: an outbox message names something that
 * must happen, carries everything the handler needs, and is claimed exactly
 * once. It is not a job queue with priorities, retries-with-backoff-strategies
 * or routing - it is a durable record of "this side effect is owed", which is
 * the minimum needed to get fan-out off the request thread without losing it.
 */
@Entity({ name: 'outbox_messages' })
@Index('IDX_outbox_messages_claim', ['availableAt', 'id'])
export class OutboxMessage {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar', length: 80 })
  kind!: OutboxMessageKind;

  /**
   * The idempotency key, and a unique index in the database. A second attempt
   * to enqueue the same logical message is a no-op rather than a duplicate
   * push, which is what makes the emergency path safe to re-run: the ordinary
   * fan-out and the emergency fan-out for one booking use different kinds but
   * the same underlying offer, so they derive their keys from the offer, not
   * from the caller.
   */
  @Column({ name: 'dedupe_key', type: 'varchar', length: 200, unique: true })
  dedupeKey!: string;

  @Column({ type: 'jsonb' })
  payload!: Record<string, unknown>;

  /** Carries the wave schedule, so escalation timing is a property of the row. */
  @Column({ name: 'available_at', type: 'timestamptz', default: () => 'now()' })
  availableAt!: Date;

  @Column({ type: 'integer', default: 0 })
  attempts!: number;

  @Column({ name: 'claimed_at', type: 'timestamptz', nullable: true })
  claimedAt!: Date | null;

  @Column({ name: 'processed_at', type: 'timestamptz', nullable: true })
  processedAt!: Date | null;

  @Column({ name: 'last_error', type: 'varchar', length: 1000, nullable: true })
  lastError!: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}

/**
 * Kept in sync with `CHK_outbox_messages_kind` by
 * `TransactiontalOutbox1789750200000`. The CHECK is the authority: an unknown
 * kind is rejected by the database rather than silently dropped by a worker
 * that has no handler for it.
 */
export type OutboxMessageKind =
  | 'booking.provider-fanout'
  | 'booking.project'
  | 'emergency.wave'
  | 'booking.requested-expiry'
  | 'booking.reminder';
