import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('review_photo_moderation_events')
@Index('IX_review_photo_events_photo', ['photoId'])
export class ReviewPhotoModerationEvent {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'photo_id' })
  photoId!: string;

  @Column('uuid', { name: 'actor_user_id' })
  actorUserId!: string;

  @Column('varchar', { name: 'from_status', length: 16, nullable: true })
  fromStatus!: string | null;

  @Column('varchar', { name: 'to_status', length: 16 })
  toStatus!: string;

  @Column('varchar', { length: 500 })
  reason!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
