import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
  UpdateDateColumn,
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

  @Column({ name: 'current_wave', type: 'smallint', default: 0 })
  currentWave!: number;

  @Column({ name: 'last_escalated_at', type: 'timestamptz', nullable: true })
  lastEscalatedAt!: Date | null;

  @Column({ name: 'wave_history', type: 'jsonb', default: '[]' })
  waveHistory!: Array<{ wave: number; at: string; eligibleCount: number }>;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
