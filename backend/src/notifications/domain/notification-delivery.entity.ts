import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export const NotificationDeliveryStatus = {
  SENT: 'SENT',
  FAILED: 'FAILED',
  NO_DEVICES: 'NO_DEVICES',
  SKIPPED_QUIET_HOURS: 'SKIPPED_QUIET_HOURS',
} as const;
export type NotificationDeliveryStatus =
  (typeof NotificationDeliveryStatus)[keyof typeof NotificationDeliveryStatus];

/** One attempted domain notification. The dedupe key makes sends replay-safe. */
@Entity('notification_deliveries')
@Index('IX_notification_deliveries_user', ['userId'])
@Index('UQ_notification_deliveries_dedupe', ['dedupeKey', 'userId'], {
  unique: true,
})
export class NotificationDelivery {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid', { name: 'user_id' })
  userId!: string;

  @Column('varchar', { length: 64 })
  kind!: string;

  @Column('varchar', { name: 'dedupe_key', length: 200 })
  dedupeKey!: string;

  @Column('uuid', { name: 'booking_id', nullable: true })
  bookingId!: string | null;

  @Column('varchar', { length: 32 })
  status!: NotificationDeliveryStatus;

  @Column('varchar', {
    name: 'provider_message_id',
    length: 200,
    nullable: true,
  })
  providerMessageId!: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
