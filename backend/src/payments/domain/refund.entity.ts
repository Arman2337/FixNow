import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/** A gateway refund against a paid order. Amounts are integer paise. */
@Entity('refunds')
@Index('IX_refunds_order', ['paymentOrderId'])
@Check('CHK_refunds_status', "status IN ('PENDING', 'PROCESSED')")
export class Refund {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'payment_order_id' })
  paymentOrderId!: string;

  @Column('varchar', { name: 'gateway_refund_id', length: 64 })
  gatewayRefundId!: string;

  /** Caller-supplied idempotency key; unique when present. */
  @Column('varchar', { name: 'request_key', length: 128, nullable: true })
  requestKey!: string | null;

  @Column('integer', { name: 'amount_minor' })
  amountMinor!: number;

  @Column('varchar', { length: 3, default: 'INR' })
  currency!: string;

  @Column('varchar', { default: 'PROCESSED' })
  status!: string;

  @Column('varchar', { length: 200 })
  reason!: string;

  @Column('uuid', { name: 'created_by' })
  createdBy!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
