import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Complaint, ComplaintStatus } from './complaint.entity';

@Entity('complaint_audits')
export class ComplaintAudit {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'complaint_id' })
  complaintId: string;

  @Column('uuid', { name: 'actor_id' })
  actorId: string;

  @Column({
    type: 'enum',
    enum: ComplaintStatus,
    name: 'previous_status',
    nullable: true,
  })
  previousStatus: ComplaintStatus | null;

  @Column({
    type: 'enum',
    enum: ComplaintStatus,
    name: 'new_status',
  })
  newStatus: ComplaintStatus;

  @Column('text', { nullable: true })
  notes: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @ManyToOne(() => Complaint, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'complaint_id' })
  complaint: Complaint;
}
