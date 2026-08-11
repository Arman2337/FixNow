import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from '../../users/user.entity';
import {
  AvailabilityException,
  ProviderAvailabilityStatus,
  WeeklyAvailabilityRule,
} from '../../../../shared/provider-availability.types';

@Entity({ name: 'provider_availability' })
export class ProviderAvailabilityEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid', unique: true })
  userId!: string;

  @OneToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: UserEntity;

  @Column({ name: 'time_zone', type: 'varchar', length: 100 })
  timeZone!: string;

  @Column({ name: 'weekly_rules', type: 'jsonb', default: () => "'[]'::jsonb" })
  weeklyRules!: WeeklyAvailabilityRule[];

  @Column({ type: 'jsonb', default: () => "'[]'::jsonb" })
  exceptions!: AvailabilityException[];

  @Column({
    type: 'varchar',
    length: 16,
    default: ProviderAvailabilityStatus.Offline,
  })
  status!: ProviderAvailabilityStatus;

  @Column({ name: 'status_expires_at', type: 'timestamptz', nullable: true })
  statusExpiresAt!: Date | null;

  @Column({ type: 'integer', default: 0 })
  version!: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
