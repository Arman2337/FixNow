import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  VersionColumn,
  OneToMany,
} from 'typeorm';
import { ComplaintEvidence } from './complaint-evidence.entity';
import { AppealStatus } from '../../../../../shared/trust.types';

export enum ComplaintStatus {
  OPEN = 'OPEN',
  IN_REVIEW = 'IN_REVIEW',
  ESCALATED = 'ESCALATED',
  RESOLVED = 'RESOLVED',
  CLOSED = 'CLOSED',
}

export enum ComplaintTargetRole {
  PROVIDER = 'PROVIDER',
  CUSTOMER = 'CUSTOMER',
  PLATFORM = 'PLATFORM',
}

@Entity('complaints')
export class Complaint {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'booking_id', nullable: true })
  bookingId: string | null;

  @Column('uuid', { name: 'submitter_id' })
  submitterId: string;

  @Column({
    type: 'enum',
    enum: ComplaintTargetRole,
    name: 'target_role',
  })
  targetRole: ComplaintTargetRole;

  @Column('uuid', { name: 'target_id', nullable: true })
  targetId: string | null;

  @Column('uuid', { name: 'assignee_id', nullable: true })
  assigneeId: string | null;

  @Column('varchar', { length: 100 })
  category: string;

  @Column('text')
  description: string;

  @Column({
    type: 'enum',
    enum: ComplaintStatus,
    default: ComplaintStatus.OPEN,
  })
  status: ComplaintStatus;

  @Column('text', { name: 'resolution_notes', nullable: true })
  resolutionNotes: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;

  @OneToMany(() => ComplaintEvidence, (evidence) => evidence.complaint)
  evidence: ComplaintEvidence[];

  @Column({
    type: 'enum',
    enum: AppealStatus,
    default: AppealStatus.NONE,
  })
  appealStatus: AppealStatus;

  @Column('text', { name: 'appeal_reason', nullable: true })
  appealReason: string | null;

  @Column('text', { name: 'appeal_resolution', nullable: true })
  appealResolution: string | null;
}
