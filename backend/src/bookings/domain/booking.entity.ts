import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  VersionColumn,
  Unique,
} from 'typeorm';
import {
  BookingStatus,
  VALID_BOOKING_TRANSITIONS,
} from '../../../../shared/booking-lifecycle.types';

@Entity('bookings')
@Unique('UQ_bookings_customer_idempotency', ['customerId', 'idempotencyKey'])
export class Booking {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'customer_id' })
  customerId: string;

  @Column('uuid', { name: 'provider_id', nullable: true })
  providerId: string | null;

  @Column('uuid', { name: 'service_category_id' })
  serviceCategoryId: string;

  @Column('varchar', { name: 'idempotency_key', length: 128 })
  idempotencyKey: string;

  @Column('char', { name: 'request_fingerprint', length: 64 })
  requestFingerprint: string;

  @Column({
    type: 'enum',
    enum: BookingStatus,
    enumName: 'booking_status',
    default: BookingStatus.REQUESTED,
  })
  status: BookingStatus;

  @Column('varchar', { length: 2000 })
  description: string;

  @Column('decimal', { name: 'location_lat', precision: 10, scale: 7 })
  locationLat: number | null;

  @Column('decimal', { name: 'location_lng', precision: 10, scale: 7 })
  locationLng: number | null;

  @Column('timestamptz', { name: 'scheduled_at', nullable: true })
  scheduledAt: Date | null;

  @Column('timestamptz', { name: 'assigned_at', nullable: true })
  assignedAt: Date | null;

  @Column('timestamptz', { name: 'en_route_at', nullable: true })
  enRouteAt: Date | null;

  @Column('timestamptz', { name: 'started_at', nullable: true })
  startedAt: Date | null;

  @Column('timestamptz', { name: 'completed_at', nullable: true })
  completedAt: Date | null;

  @Column('timestamptz', { name: 'cancelled_at', nullable: true })
  cancelledAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz' })
  deletedAt: Date | null;

  @VersionColumn()
  version: number;

  @Column('varchar', {
    name: 'cancellation_reason',
    length: 500,
    nullable: true,
  })
  cancellationReason: string | null;

  /**
   * Enforces strict state machine rules when changing the booking status.
   * Throws an error if an illegal transition is attempted.
   */
  transitionTo(newStatus: BookingStatus, reason?: string, now = new Date()) {
    const allowed = VALID_BOOKING_TRANSITIONS[this.status];
    if (!allowed || !allowed.includes(newStatus)) {
      throw new Error(`Invalid transition from ${this.status} to ${newStatus}`);
    }
    if (newStatus === BookingStatus.CANCELLED && !reason?.trim()) {
      throw new Error(
        'A cancellation reason must be provided when cancelling a booking',
      );
    }
    if (newStatus === BookingStatus.CANCELLED) {
      this.cancellationReason = reason!.trim();
      this.cancelledAt = now;
    } else if (newStatus === BookingStatus.ASSIGNED) {
      this.assignedAt = now;
    } else if (newStatus === BookingStatus.EN_ROUTE) {
      this.enRouteAt = now;
    } else if (newStatus === BookingStatus.IN_PROGRESS) {
      this.startedAt = now;
    } else if (newStatus === BookingStatus.COMPLETED) {
      this.completedAt = now;
    }
    this.status = newStatus;
  }
}
