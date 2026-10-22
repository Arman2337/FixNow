import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

import { GuaranteeClaimStatus } from '../../../../shared/guarantee-lifecycle.types';
export { GuaranteeClaimStatus } from '../../../../shared/guarantee-lifecycle.types';

@Entity('guarantee_claims')
export class GuaranteeClaim {
  @VersionColumn()
  version: number;

  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'booking_id' })
  bookingId: string;

  @Column('uuid', { name: 'customer_id' })
  customerId: string;

  @Column('uuid', { name: 'original_provider_id', nullable: true })
  originalProviderId: string | null;

  @Column({
    type: 'enum',
    enum: GuaranteeClaimStatus,
    enumName: 'guarantee_claims_status_enum',
    default: GuaranteeClaimStatus.PENDING,
  })
  status: GuaranteeClaimStatus;

  @Column('text')
  description: string;

  @Column('jsonb', { name: 'evidence_urls', nullable: true })
  evidenceUrls: string[] | null;

  @Column('text', { name: 'admin_notes', nullable: true })
  adminNotes: string | null;

  @Column('uuid', { name: 'assigned_provider_id', nullable: true })
  assignedProviderId: string | null;

  @Column('uuid', { name: 're_service_booking_id', nullable: true })
  reServiceBookingId: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
