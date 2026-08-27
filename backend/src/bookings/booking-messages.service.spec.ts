import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import type { Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { Booking } from './domain/booking.entity';
import { BookingMessage } from './domain/booking-message.entity';
import { BookingMessagesService } from './booking-messages.service';
import type { BookingProjectionService } from '../realtime/booking-projection.service';
import type { DomainNotificationService } from '../notifications/domain/domain-notification.service';

describe('BookingMessagesService', () => {
  let service: BookingMessagesService;
  let bookingsRepo: jest.Mocked<Repository<Booking>>;
  let messagesRepo: jest.Mocked<Repository<BookingMessage>>;
  let projections: jest.Mocked<BookingProjectionService>;
  let notifications: jest.Mocked<DomainNotificationService>;

  const customerId = '00000000-0000-4000-8000-000000000001';
  const providerId = '00000000-0000-4000-8000-000000000002';
  const strangerId = '00000000-0000-4000-8000-000000000099';
  const bookingId = '00000000-0000-4000-8000-000000000101';

  const mockBooking = (status = BookingStatus.ASSIGNED): Booking =>
    Object.assign(new Booking(), {
      id: bookingId,
      customerId,
      providerId,
      status,
      version: 1,
    });

  const mockMessage = (
    overrides: Partial<BookingMessage> = {},
  ): BookingMessage =>
    Object.assign(new BookingMessage(), {
      id: '00000000-0000-4000-8000-000000000201',
      bookingId,
      senderUserId: customerId,
      senderRole: 'CUSTOMER',
      clientMessageId: 'client-1',
      messageText: 'Buzz code is #402',
      readAt: null,
      createdAt: new Date('2026-08-27T10:00:00Z'),
      ...overrides,
    });

  beforeEach(() => {
    bookingsRepo = {
      findOne: jest.fn(),
    } as unknown as jest.Mocked<Repository<Booking>>;

    messagesRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn((dto) =>
        Object.assign(new BookingMessage(), dto, {
          id: 'new-msg-id',
          createdAt: new Date(),
        }),
      ),
      save: jest.fn((entity) => Promise.resolve(entity)),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    } as unknown as jest.Mocked<Repository<BookingMessage>>;

    projections = {
      publishChatMessage: jest.fn(),
      isSubscriberActive: jest.fn().mockReturnValue(false),
    } as unknown as jest.Mocked<BookingProjectionService>;

    notifications = {
      notifyChatMessage: jest.fn().mockResolvedValue(undefined),
    } as unknown as jest.Mocked<DomainNotificationService>;

    service = new BookingMessagesService(
      bookingsRepo,
      messagesRepo,
      projections,
      notifications,
    );
  });

  describe('listMessages', () => {
    it('returns messages and canSend=true for active customer', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );
      messagesRepo.find.mockResolvedValue([mockMessage()]);

      const result = await service.listMessages(bookingId, customerId);

      expect(result.canSend).toBe(true);
      expect(result.messages).toHaveLength(1);
      expect(result.messages[0].messageText).toBe('Buzz code is #402');
      expect(messagesRepo.update).toHaveBeenCalled();
    });

    it('returns canSend=false for completed booking', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.COMPLETED),
      );
      messagesRepo.find.mockResolvedValue([mockMessage()]);

      const result = await service.listMessages(bookingId, customerId);

      expect(result.canSend).toBe(false);
      expect(result.messages).toHaveLength(1);
    });

    it('rejects third-party user with ForbiddenException', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );

      await expect(service.listMessages(bookingId, strangerId)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('throws NotFoundException when booking does not exist', async () => {
      bookingsRepo.findOne.mockResolvedValue(null);

      await expect(service.listMessages(bookingId, customerId)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('sendMessage', () => {
    it('saves, broadcasts, and notifies for valid message during ASSIGNED status', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );
      messagesRepo.findOne.mockResolvedValue(null);

      const result = await service.sendMessage(bookingId, customerId, {
        messageText: 'I am by the gate',
        clientMessageId: 'c-123',
      });

      expect(result.messageText).toBe('I am by the gate');
      expect(result.senderRole).toBe('CUSTOMER');
      expect(projections.publishChatMessage).toHaveBeenCalledWith(
        bookingId,
        expect.objectContaining({ messageText: 'I am by the gate' }),
      );
      expect(notifications.notifyChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        providerId,
        'provider',
        'new-msg-id',
      );
    });

    it('returns existing message if clientMessageId already exists (idempotent)', async () => {
      const existing = mockMessage({
        clientMessageId: 'c-123',
        messageText: 'Duplicate send',
      });
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );
      messagesRepo.findOne.mockResolvedValue(existing);

      const result = await service.sendMessage(bookingId, customerId, {
        messageText: 'Duplicate send',
        clientMessageId: 'c-123',
      });

      expect(result.id).toBe(existing.id);
      expect(messagesRepo.save).not.toHaveBeenCalled();
    });

    it('rejects sending when booking is COMPLETED with ConflictException', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.COMPLETED),
      );

      await expect(
        service.sendMessage(bookingId, customerId, { messageText: 'Hello' }),
      ).rejects.toThrow(ConflictException);
    });

    it('rejects sending when booking is CANCELLED with ConflictException', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.CANCELLED),
      );

      await expect(
        service.sendMessage(bookingId, customerId, { messageText: 'Hello' }),
      ).rejects.toThrow(ConflictException);
    });

    it('rejects empty or whitespace-only message with BadRequestException', async () => {
      await expect(
        service.sendMessage(bookingId, customerId, { messageText: '   ' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects message exceeding 2000 chars with BadRequestException', async () => {
      await expect(
        service.sendMessage(bookingId, customerId, {
          messageText: 'a'.repeat(2001),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects stranger sender with ForbiddenException', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );

      await expect(
        service.sendMessage(bookingId, strangerId, { messageText: 'Hi' }),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
