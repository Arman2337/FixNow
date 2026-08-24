import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ProviderSkillEntity } from '../providers/provider-skill.entity';

@Entity({ name: 'service_categories' })
@Check(
  'CHK_service_categories_pricing_pair',
  '(price_amount IS NULL AND price_currency IS NULL) OR (price_amount IS NOT NULL AND price_currency IS NOT NULL)',
)
export class ServiceCategoryEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /**
   * Optional admin-published flat base price in minor currency units
   * (paise for INR). Null on both fields means "price on request"; the
   * table-level check constraint keeps the pair consistent.
   */
  @Column({ name: 'price_amount', type: 'integer', nullable: true })
  priceAmount!: number | null;

  @Column({
    name: 'price_currency',
    type: 'varchar',
    length: 3,
    nullable: true,
  })
  priceCurrency!: string | null;

  /** API-facing view; null means "price on request". */
  get pricing(): { amountMinor: number; currency: string } | null {
    if (this.priceAmount === null || this.priceCurrency === null) return null;
    return { amountMinor: this.priceAmount, currency: this.priceCurrency };
  }

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
