import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Complaint } from './complaint.entity';

@Entity('complaint_evidence')
export class ComplaintEvidence {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'complaint_id' })
  complaintId: string;

  @Column('uuid', { name: 'uploaded_by' })
  uploadedBy: string;

  @Column('varchar', { name: 'file_url', length: 500 })
  fileUrl: string;

  @Column('varchar', { name: 'file_type', length: 50 })
  fileType: string;

  @Column('varchar', { length: 255, nullable: true })
  description: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @ManyToOne(() => Complaint, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'complaint_id' })
  complaint: Complaint;
}
