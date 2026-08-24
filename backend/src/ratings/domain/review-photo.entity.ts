import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export const ReviewPhotoStatus = {
  PENDING: 'PENDING',
  APPROVED: 'APPROVED',
  REJECTED: 'REJECTED',
} as const;
export type ReviewPhotoStatus =
  (typeof ReviewPhotoStatus)[keyof typeof ReviewPhotoStatus];

@Entity('review_photos')
@Index('IX_review_photos_review', ['reviewId'])
@Check(
  'CHK_review_photos_status',
  "status IN ('PENDING', 'APPROVED', 'REJECTED')",
)
export class ReviewPhoto {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'review_id' })
  reviewId!: string;

  @Column('uuid', { name: 'uploaded_by' })
  uploadedBy!: string;

  /** Quarantine-prefixed opaque storage key; never a public URL. */
  @Column('varchar', { name: 'object_key', length: 512 })
  objectKey!: string;

  @Column('varchar', { name: 'content_type', length: 100 })
  contentType!: string;

  @Column('integer', { name: 'size_bytes' })
  sizeBytes!: number;

  @Column('char', { length: 64 })
  sha256!: string;

  /** Moderation gate: never publicly visible until APPROVED. */
  @Column('varchar', { default: ReviewPhotoStatus.PENDING })
  status!: ReviewPhotoStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
