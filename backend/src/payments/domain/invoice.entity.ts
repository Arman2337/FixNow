import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

/** One invoice per paid payment order, generated exactly once (FN-053). */
@Entity('invoices')
export class Invoice {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'payment_order_id' })
  paymentOrderId!: string;

  /** Sequential public number, e.g. FN-2026-000001. */
  @Column('varchar', { name: 'invoice_number', length: 32 })
  invoiceNumber!: string;

  @Column('timestamptz', { name: 'issued_at' })
  issuedAt!: Date;

  @Column('integer', { name: 'subtotal_amount_minor', default: 0 })
  subtotalAmountMinor!: number;

  @Column('integer', { name: 'tax_amount_minor', default: 0 })
  taxAmountMinor!: number;

  @Column('integer', { name: 'discount_amount_minor', default: 0 })
  discountAmountMinor!: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
