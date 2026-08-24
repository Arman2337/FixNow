import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';
import { ReviewModerationStatus } from '../../../../shared/ratings.types';

@Entity('booking_reviews')
@Unique('UQ_booking_reviews_booking', ['bookingId'])
@Check('CHK_booking_reviews_rating', 'rating BETWEEN 1 AND 5')
export class BookingReview {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'booking_id' })
  bookingId: string;

  @Column('uuid', { name: 'customer_id' })
  customerId: string;

  @Column('uuid', { name: 'provider_id' })
  providerId: string;

  @Column('smallint')
  rating: number;

  @Column('varchar', { name: 'review_text', length: 1000, nullable: true })
  reviewText: string | null;

  @Column({
    type: 'enum',
    enum: ReviewModerationStatus,
    enumName: 'review_moderation_status',
    name: 'moderation_status',
    default: ReviewModerationStatus.PUBLISHED,
  })
  moderationStatus: ReviewModerationStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
