import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * Immutable payment audit event. The (order, event, digest) unique index
 * makes webhook replays idempotent: the same payload can never apply twice.
 */
@Entity('payment_events')
@Index('IX_payment_events_order', ['orderId'])
@Index('UQ_payment_events_replay', ['orderId', 'eventType', 'payloadDigest'], {
  unique: true,
})
export class PaymentEvent {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'order_id' })
  orderId!: string;

  @Column('varchar', { name: 'event_type', length: 64 })
  eventType!: string;

  /** SHA-256 of the raw verified payload. */
  @Column('char', { name: 'payload_digest', length: 64 })
  payloadDigest!: string;

  @Column('varchar', { length: 64 })
  actor!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
