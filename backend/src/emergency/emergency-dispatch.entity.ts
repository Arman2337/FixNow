import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';

/**
 * FN-063 sidecar: priority-dispatch state for an emergency booking. The
 * booking keeps the single lifecycle; this row only tracks escalation waves
 * (docs/safety/emergency-dispatch-policy-v1.md §4).
 */
@Entity('emergency_dispatches')
export class EmergencyDispatch {
  @PrimaryColumn('uuid', { name: 'booking_id' })
  bookingId!: string;

  @OneToOne(() => Booking, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'booking_id' })
  booking!: Booking;

  /**
   * BUG-009. Denormalised from `bookings.customer_id` so "is this customer
   * already in an emergency" is a property of this row rather than of a join.
   *
   * The rule is then expressible as a partial unique index, which means the
   * database enforces it atomically: a read-then-write check in application code
   * loses to any retry that interleaves, and the Idempotency-Key header only
   * covers a double tap.
   */
  @Column({ name: 'customer_id', type: 'uuid' })
  customerId!: string;

  @Column({ name: 'current_wave', type: 'smallint', default: 0 })
  currentWave!: number;

  @Column({ name: 'last_escalated_at', type: 'timestamptz', nullable: true })
  lastEscalatedAt!: Date | null;

  /**
   * BUG-009. When the emergency stopped being open.
   *
   * `NULL` means open, and the unique index is built on that. It is what makes
   * the gate reusable: without it, a customer who cancelled an emergency would
   * be blocked from raising another one for the lifetime of the row.
   */
  @Column({ name: 'closed_at', type: 'timestamptz', nullable: true })
  closedAt!: Date | null;

  /**
   * BUG-015. Optimistic-locking version for the `waveHistory` append.
   *
   * `waveHistory` is a read-modify-write on a jsonb column, so two concurrent
   * wave escalations silently dropped one another's entry - and that is exactly
   * the record needed when a customer disputes what happened during an
   * emergency. `bookings` carries the same column for the same reason.
   */
  @VersionColumn()
  version!: number;

  @Column({ name: 'wave_history', type: 'jsonb', default: '[]' })
  waveHistory!: Array<{ wave: number; at: string; eligibleCount: number }>;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
