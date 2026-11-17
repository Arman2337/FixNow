import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export const PaymentOrderStatus = {
  CREATED: 'CREATED',
  PAID: 'PAID',
  FAILED: 'FAILED',
  CANCELLED: 'CANCELLED',
} as const;
export type PaymentOrderStatus =
  (typeof PaymentOrderStatus)[keyof typeof PaymentOrderStatus];

/** Booking-bound payment order. Amounts are integer paise (ADR-0016). */
@Entity('payment_orders')
@Index('IX_payment_orders_booking', ['bookingId'])
@Index('UQ_payment_orders_group_customer', ['groupServiceId', 'customerId'], {
  unique: true,
  where: 'group_service_id IS NOT NULL',
})
@Check(
  'CHK_payment_orders_subject',
  'num_nonnulls(booking_id, group_service_id) = 1',
)
@Check(
  'CHK_payment_orders_status',
  "status IN ('CREATED', 'PAID', 'FAILED', 'CANCELLED')",
)
export class PaymentOrder {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'booking_id', nullable: true })
  bookingId!: string | null;

  @Column('uuid', { name: 'group_service_id', nullable: true })
  groupServiceId!: string | null;

  @Column('uuid', { name: 'customer_id' })
  customerId!: string;

  @Column('integer', { name: 'amount_minor' })
  amountMinor!: number;

  @Column('varchar', { length: 3, default: 'INR' })
  currency!: string;

  @Column('varchar', { default: PaymentOrderStatus.CREATED })
  status!: PaymentOrderStatus;

  @Column('varchar', { name: 'gateway_order_id', length: 64 })
  gatewayOrderId!: string;

  /** Booking-scoped idempotency reference; unique per order. */
  @Column('varchar', { length: 128 })
  receipt!: string;

  @Column('varchar', { name: 'gateway_payment_id', length: 64, nullable: true })
  gatewayPaymentId!: string | null;

  @Column('varchar', { name: 'failure_reason', length: 200, nullable: true })
  failureReason!: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
