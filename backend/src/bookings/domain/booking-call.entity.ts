import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Booking } from './booking.entity';
import type { ChatSenderRole } from '../../../../shared/booking-chat.types';
import type { CallStatus } from '../../../../shared/booking-call.types';

@Entity({ name: 'booking_calls' })
export class BookingCall {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'booking_id', type: 'uuid' })
  bookingId!: string;

  @ManyToOne(() => Booking, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'booking_id' })
  booking!: Booking;

  @Column({ name: 'caller_user_id', type: 'uuid' })
  callerUserId!: string;

  @Column({ name: 'caller_role', type: 'varchar', length: 20 })
  callerRole!: ChatSenderRole;

  @Column({ name: 'callee_user_id', type: 'uuid' })
  calleeUserId!: string;

  @Column({ name: 'status', type: 'varchar', length: 20, default: 'INITIATED' })
  status!: CallStatus;

  @CreateDateColumn({ name: 'started_at', type: 'timestamptz' })
  startedAt!: Date;

  @Column({ name: 'connected_at', type: 'timestamptz', nullable: true })
  connectedAt!: Date | null;

  @Column({ name: 'ended_at', type: 'timestamptz', nullable: true })
  endedAt!: Date | null;

  @Column({ name: 'duration_seconds', type: 'integer', nullable: true })
  durationSeconds!: number | null;
}
