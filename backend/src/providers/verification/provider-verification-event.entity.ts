import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { ProviderOnboardingStatus } from '../provider-onboarding-status';

@Entity({ name: 'provider_verification_events' })
export class ProviderVerificationEventEntity {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'application_id', type: 'uuid' }) applicationId!: string;
  @Column({ name: 'actor_user_id', type: 'uuid' }) actorUserId!: string;
  @Column({ name: 'from_status', type: 'varchar', length: 40 })
  fromStatus!: ProviderOnboardingStatus;
  @Column({ name: 'to_status', type: 'varchar', length: 40 })
  toStatus!: ProviderOnboardingStatus;
  @Column({ type: 'varchar', length: 1000 }) reason!: string;
  @Column({ name: 'application_version', type: 'integer' })
  applicationVersion!: number;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
