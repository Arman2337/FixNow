import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ServiceCategoryEntity } from './service-category.entity';

@Entity({ name: 'sub_services' })
export class SubServiceEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'category_id' })
  categoryId!: string;

  @ManyToOne(() => ServiceCategoryEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'category_id' })
  category!: ServiceCategoryEntity;

  @Column('varchar', { length: 255 })
  name!: string;

  @Column('text', { nullable: true })
  description!: string | null;

  @Column('integer', { name: 'price_minor', nullable: true })
  priceMinor!: number | null;

  @Column('varchar', { length: 3, nullable: true, default: 'INR' })
  currency!: string | null;

  @Column('integer', { name: 'estimated_duration_minutes', nullable: true })
  estimatedDurationMinutes!: number | null;

  @Column('varchar', { length: 100, nullable: true })
  badge!: string | null;

  @Column('varchar', { name: 'image_url', length: 1024, nullable: true })
  imageUrl!: string | null;

  @Column('boolean', { name: 'is_active', default: true })
  isActive!: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
