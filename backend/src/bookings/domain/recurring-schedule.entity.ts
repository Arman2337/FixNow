import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import type {
  ScheduleCadence,
  ScheduleStatus,
} from '../../../../shared/recurring.types';

@Entity({ name: 'recurring_schedules' })
@Index('IX_recurring_schedules_customer', ['customerId'])
export class RecurringSchedule {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'customer_id' })
  customerId!: string;

  @Column('uuid', { name: 'service_category_id' })
  serviceCategoryId!: string;

  @Column('varchar', { length: 2000 })
  description!: string;

  @Column('decimal', { name: 'location_lat', precision: 10, scale: 7 })
  locationLat!: number;

  @Column('decimal', { name: 'location_lng', precision: 10, scale: 7 })
  locationLng!: number;

  @Column('varchar', { length: 16 })
  cadence!: ScheduleCadence;

  @Column('varchar', { length: 16, default: 'ACTIVE' })
  status!: ScheduleStatus;

  @Column('timestamptz', { name: 'next_occurrence_at' })
  nextOccurrenceAt!: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
