import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from '../users/user.entity';
import { ProviderOnboardingStatus } from './provider-onboarding-status';

@Entity({ name: 'provider_applications' })
export class ProviderApplicationEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid', unique: true })
  userId!: string;

  @OneToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: UserEntity;

  @Column({
    type: 'enum',
    enum: ProviderOnboardingStatus,
    enumName: 'provider_onboarding_status',
    default: ProviderOnboardingStatus.Unverified,
  })
  status!: ProviderOnboardingStatus;

  @Column({ name: 'assigned_reviewer_user_id', type: 'uuid', nullable: true })
  assignedReviewerUserId!: string | null;

  @Column({
    name: 'decision_reason',
    type: 'varchar',
    length: 1000,
    nullable: true,
  })
  decisionReason!: string | null;

  @Column({ name: 'reviewed_at', type: 'timestamptz', nullable: true })
  reviewedAt!: Date | null;

  @Column({ type: 'integer', default: 0 })
  version!: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
