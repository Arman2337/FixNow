import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('in_app_notifications')
export class InAppNotification {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'user_id' })
  userId!: string;

  @Column('varchar', { length: 255 })
  title!: string;

  @Column('text')
  body!: string;

  @Column('varchar', { length: 64 })
  kind!: string;

  @Column('uuid', { name: 'booking_id', nullable: true })
  bookingId!: string | null;

  @Column('uuid', { name: 'payment_id', nullable: true })
  paymentId!: string | null;

  @Column('timestamptz', { name: 'read_at', nullable: true })
  readAt!: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
