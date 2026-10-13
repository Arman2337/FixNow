import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';

export const JobProofStage = {
  BEFORE: 'BEFORE',
  AFTER: 'AFTER',
} as const;
export type JobProofStage = (typeof JobProofStage)[keyof typeof JobProofStage];

/**
 * FN-142. A photograph the assigned provider captured on site, as evidence of
 * the condition of the job.
 *
 * Deliberately modelled per booking and per stage rather than as a general
 * photo album: the customer is shown one before and one after, side by side,
 * and that pairing is the whole feature. The unique (booking, stage) index is
 * therefore part of the contract, not a storage optimisation - it is what makes
 * "the before photo" singular instead of "the newest of several".
 *
 * Storage follows the review-photo pipeline exactly: a quarantine-prefixed
 * opaque key, a malware scan before the row is written, and no public URL ever.
 * `objectKey` is deliberately absent from every API response; bytes are served
 * only through the participant-checked content endpoint.
 */
@Entity('job_proof_photos')
@Index('IDX_job_proof_photos_booking', ['bookingId'])
@Unique('UQ_job_proof_photos_booking_stage', ['bookingId', 'stage'])
@Check('CHK_job_proof_photos_stage', "stage IN ('BEFORE', 'AFTER')")
@Check('CHK_job_proof_photos_size', 'size_bytes > 0')
export class JobProofPhoto {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'booking_id' })
  bookingId!: string;

  @Column('varchar', { length: 8 })
  stage!: JobProofStage;

  /** The assigned provider who captured it. */
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

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
