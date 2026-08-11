import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from '../users/user.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';

@Entity({ name: 'provider_skills' })
@Unique(['userId', 'serviceCategoryId'])
export class ProviderSkillEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: UserEntity;

  @Column({ name: 'service_category_id', type: 'uuid' })
  serviceCategoryId!: string;

  @ManyToOne(
    () => ServiceCategoryEntity,
    (category) => category.providerSkills,
    { onDelete: 'CASCADE' },
  )
  @JoinColumn({ name: 'service_category_id' })
  serviceCategory!: ServiceCategoryEntity;

  @Column({ name: 'years_experience', type: 'integer', nullable: true })
  yearsExperience!: number | null;

  @Column({ name: 'hourly_rate_cents', type: 'integer', nullable: true })
  hourlyRateCents!: number | null;

  @Column({ name: 'visit_fee_cents', type: 'integer', nullable: true })
  visitFeeCents!: number | null;

  @Column({ type: 'text', nullable: true })
  description!: string | null;

  @Column({ name: 'is_verified', type: 'boolean', default: false })
  isVerified!: boolean;

  @Column({ name: 'verification_notes', type: 'text', nullable: true })
  verificationNotes!: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
