import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  VersionColumn,
} from 'typeorm';
import { BookingStatus, ValidBookingTransitions } from '../../../../shared/booking-lifecycle.types';

@Entity('bookings')
export class Booking {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  customerId: string;

  @Column('uuid', { nullable: true })
  providerId: string | null;

  @Column('uuid')
  serviceCategoryId: string;

  @Column({
    type: 'enum',
    enum: BookingStatus,
    default: BookingStatus.REQUESTED,
  })
  status: BookingStatus;

  @Column('text')
  description: string;

  @Column('decimal', { precision: 10, scale: 7 })
  locationLat: number;

  @Column('decimal', { precision: 10, scale: 7 })
  locationLng: number;

  @Column('timestamp', { nullable: true })
  scheduledAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date | null;

  @VersionColumn()
  version: number;

  @Column('text', { nullable: true })
  cancellationReason: string | null;

  /**
   * Enforces strict state machine rules when changing the booking status.
   * Throws an error if an illegal transition is attempted.
   */
  transitionTo(newStatus: BookingStatus, reason?: string) {
    const allowed = ValidBookingTransitions[this.status];
    if (!allowed || !allowed.includes(newStatus)) {
      throw new Error(`Invalid transition from ${this.status} to ${newStatus}`);
    }
    if (newStatus === BookingStatus.CANCELLED && !reason) {
      throw new Error('A cancellation reason must be provided when cancelling a booking');
    }
    if (newStatus === BookingStatus.CANCELLED) {
      this.cancellationReason = reason || null;
    }
    this.status = newStatus;
  }
}
