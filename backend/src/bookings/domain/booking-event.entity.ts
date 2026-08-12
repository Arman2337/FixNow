import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { BookingStatus } from '../../../../shared/booking-lifecycle.types';
import { Booking } from './booking.entity';

@Entity({ name: 'booking_events' })
export class BookingEvent {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'booking_id', type: 'uuid' })
  bookingId!: string;

  @ManyToOne(() => Booking, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'booking_id' })
  booking!: Booking;

  @Column({ name: 'actor_user_id', type: 'uuid' })
  actorUserId!: string;

  @Column({
    name: 'from_status',
    type: 'enum',
    enum: BookingStatus,
    enumName: 'booking_status',
    nullable: true,
  })
  fromStatus!: BookingStatus | null;

  @Column({
    name: 'to_status',
    type: 'enum',
    enum: BookingStatus,
    enumName: 'booking_status',
  })
  toStatus!: BookingStatus;

  @Column({ type: 'varchar', length: 500, nullable: true })
  reason!: string | null;

  @Column({ name: 'booking_version', type: 'integer' })
  bookingVersion!: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
