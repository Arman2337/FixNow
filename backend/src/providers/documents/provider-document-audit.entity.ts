import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity({ name: 'provider_document_audit_events' })
export class ProviderDocumentAuditEntity {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'document_id', type: 'uuid' }) documentId!: string;
  @Column({ name: 'actor_user_id', type: 'uuid' }) actorUserId!: string;
  @Column({ type: 'varchar', length: 30 }) action!: string;
  @Column({ type: 'varchar', length: 20 }) outcome!: string;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
