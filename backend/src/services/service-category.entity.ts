import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ProviderSkillEntity } from '../providers/provider-skill.entity';

@Entity({ name: 'service_categories' })
export class ServiceCategoryEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  name!: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  slug!: string;

  @Column({ type: 'text', nullable: true })
  description!: string | null;

  @Column({ name: 'icon_name', type: 'varchar', length: 100, nullable: true })
  iconName!: string | null;

  @Column({ name: 'display_order', type: 'integer', default: 0 })
  displayOrder!: number;

  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive!: boolean;

  @Column({ name: 'is_emergency', type: 'boolean', default: false })
  isEmergency!: boolean;

  @OneToMany(() => ProviderSkillEntity, (skill) => skill.serviceCategory)
  providerSkills!: ProviderSkillEntity[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
