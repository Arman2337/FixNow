import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  type Relation,
  UpdateDateColumn,
} from 'typeorm';
import { Booking } from './booking.entity';
import { SubServiceEntity } from '../../services/sub-service.entity';

@Entity({ name: 'booking_line_items' })
export class BookingLineItem {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'booking_id' })
  bookingId!: string;

  @ManyToOne(() => Booking, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'booking_id' })
  booking!: Relation<Booking>;

  @Column('uuid', { name: 'sub_service_id' })
  subServiceId!: string;

  @ManyToOne(() => SubServiceEntity)
  @JoinColumn({ name: 'sub_service_id' })
  subService!: SubServiceEntity;

  @Column('integer')
  quantity!: number;

  @Column('integer', { name: 'price_minor' })
  priceMinor!: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
