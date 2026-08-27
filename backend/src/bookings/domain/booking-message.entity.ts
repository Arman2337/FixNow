import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Booking } from './booking.entity';
import type { ChatSenderRole } from '../../../../shared/booking-chat.types';

@Entity({ name: 'booking_messages' })
export class BookingMessage {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'booking_id', type: 'uuid' })
  bookingId!: string;

  @ManyToOne(() => Booking, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'booking_id' })
  booking!: Booking;

  @Column({ name: 'sender_user_id', type: 'uuid' })
  senderUserId!: string;

  @Column({ name: 'sender_role', type: 'varchar', length: 20 })
  senderRole!: ChatSenderRole;

  @Column({ name: 'client_message_id', type: 'varchar', length: 64, nullable: true })
  clientMessageId!: string | null;

  @Column({ name: 'message_text', type: 'text' })
  messageText!: string;

  @Column({ name: 'read_at', type: 'timestamptz', nullable: true })
  readAt!: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
