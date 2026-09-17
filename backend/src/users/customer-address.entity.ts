import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { CustomerProfileEntity } from './customer-profile.entity';

@Entity({ name: 'customer_addresses' })
export class CustomerAddressEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'user_id' })
  userId!: string;

  @ManyToOne(() => CustomerProfileEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  customer!: CustomerProfileEntity;

  @Column('varchar', { length: 50, nullable: true })
  label!: string | null;

  @Column('varchar', { length: 255 })
  street!: string;

  @Column('varchar', { length: 100 })
  city!: string;

  @Column('varchar', { length: 100 })
  state!: string;

  @Column('varchar', { length: 20 })
  zip!: string;

  @Column('decimal', { precision: 10, scale: 7 })
  latitude!: number;

  @Column('decimal', { precision: 10, scale: 7 })
  longitude!: number;

  @Column('boolean', { name: 'is_default', default: false })
  isDefault!: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
