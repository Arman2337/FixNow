import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';
import {
  TrustSignalSeverity,
  TrustSignalStatus,
} from '../../../../shared/trust.types';

@Entity('trust_signals')
@Unique('UQ_trust_signals_subject_rule_window', [
  'subjectType',
  'subjectId',
  'ruleCode',
  'windowStart',
])
export class TrustSignal {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column('varchar', { name: 'subject_type', length: 24 }) subjectType: string;
  @Column('uuid', { name: 'subject_id' }) subjectId: string;
  @Column('varchar', { name: 'rule_code', length: 80 }) ruleCode: string;
  @Column('varchar', { name: 'window_start', length: 32 }) windowStart: string;
  @Column({
    type: 'enum',
    enum: TrustSignalSeverity,
    enumName: 'trust_signal_severity',
  })
  severity: TrustSignalSeverity;
  @Column('varchar', { name: 'evidence_summary', length: 500 })
  evidenceSummary: string;
  @Column({
    type: 'enum',
    enum: TrustSignalStatus,
    enumName: 'trust_signal_status',
    default: TrustSignalStatus.OPEN,
  })
  status: TrustSignalStatus;
  @Column('uuid', { name: 'reviewed_by', nullable: true }) reviewedBy:
    string | null;
  @Column('timestamptz', { name: 'reviewed_at', nullable: true })
  reviewedAt: Date | null;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
  @VersionColumn() version: number;
}
