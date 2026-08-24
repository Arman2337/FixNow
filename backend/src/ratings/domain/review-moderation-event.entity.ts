import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { ReviewModerationStatus } from '../../../../shared/ratings.types';

@Entity('review_moderation_events')
export class ReviewModerationEvent {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column('uuid', { name: 'review_id' }) reviewId: string;
  @Column('uuid', { name: 'actor_user_id' }) actorUserId: string;
  @Column({
    type: 'enum',
    enum: ReviewModerationStatus,
    enumName: 'review_moderation_status',
    name: 'from_status',
  })
  fromStatus: ReviewModerationStatus;
  @Column({
    type: 'enum',
    enum: ReviewModerationStatus,
    enumName: 'review_moderation_status',
    name: 'to_status',
  })
  toStatus: ReviewModerationStatus;
  @Column('varchar', { length: 500 }) reason: string;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
