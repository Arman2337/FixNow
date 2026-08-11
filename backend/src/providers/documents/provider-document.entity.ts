import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export type ProviderDocumentStatus =
  'quarantined' | 'available' | 'rejected' | 'deleted';

@Entity({ name: 'provider_documents' })
export class ProviderDocumentEntity {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'user_id', type: 'uuid' }) userId!: string;
  @Column({ name: 'document_type', type: 'varchar', length: 40 })
  documentType!: string;
  @Column({ name: 'object_key', type: 'varchar', length: 160, unique: true })
  objectKey!: string;
  @Column({ name: 'content_type', type: 'varchar', length: 80 })
  contentType!: string;
  @Column({ name: 'size_bytes', type: 'integer' }) sizeBytes!: number;
  @Column({ name: 'sha256', type: 'char', length: 64 }) sha256!: string;
  @Column({ type: 'varchar', length: 20 }) status!: ProviderDocumentStatus;
  @Column({ name: 'retention_until', type: 'timestamptz' })
  retentionUntil!: Date;
  @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt!: Date | null;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
