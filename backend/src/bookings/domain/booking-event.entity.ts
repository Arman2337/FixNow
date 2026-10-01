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

  /**
   * Who performed the transition.
   *
   * Nullable since the REQUESTED sweeper (BUG-014): a transition the platform
   * makes on its own behalf has no honest user to attribute it to. A null here
   * with an explicit `reason` is a truthful record - "no user did this" - where
   * a real user's id would falsely accuse them and a service account would need
   * provisioning, rotation and auditing as though it were a person.
   */
  @Column({ name: 'actor_user_id', type: 'uuid', nullable: true })
  actorUserId!: string | null;

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

  /**
   * The booking version this event was recorded at.
   *
   * Nullable for events that are not state transitions. The emergency wave
   * dispatch records a fan-out without a status change, and there is no version
   * to point at: attributing it to whatever version happened to be current would
   * imply a transition that did not occur.
   */
  @Column({ name: 'booking_version', type: 'integer', nullable: true })
  bookingVersion!: number | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
