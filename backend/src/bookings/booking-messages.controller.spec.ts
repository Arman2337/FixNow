import { BookingMessagesController } from './booking-messages.controller';
import type { BookingMessagesService } from './booking-messages.service';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

describe('BookingMessagesController', () => {
  let controller: BookingMessagesController;
  let service: jest.Mocked<BookingMessagesService>;

  const userId = '00000000-0000-4000-8000-000000000001';
  const bookingId = '00000000-0000-4000-8000-000000000101';

  const req = {
    authorizationPrincipal: { userId, roles: ['customer'] },
  } as unknown as AuthorizedRequest;

  beforeEach(() => {
    service = {
      listMessages: jest.fn(),
      sendMessage: jest.fn(),
    } as unknown as jest.Mocked<BookingMessagesService>;

    controller = new BookingMessagesController(service);
  });

  it('delegates list to service with principal userId', async () => {
    service.listMessages.mockResolvedValue({ messages: [], canSend: true });

    const result = await controller.list(req, bookingId);

    expect(service.listMessages).toHaveBeenCalledWith(bookingId, userId);
    expect(result.canSend).toBe(true);
  });

  it('delegates send to service with principal userId and body', async () => {
    const mockMessage = {
      id: 'm-1',
      bookingId,
      senderUserId: userId,
      senderRole: 'CUSTOMER' as const,
      clientMessageId: 'c-1',
      messageText: 'Hello',
      readAt: null,
      createdAt: '2026-08-27T10:00:00Z',
    };
    service.sendMessage.mockResolvedValue(mockMessage);

    const result = await controller.send(req, bookingId, {
      messageText: 'Hello',
      clientMessageId: 'c-1',
    });

    expect(service.sendMessage).toHaveBeenCalledWith(bookingId, userId, {
      messageText: 'Hello',
      clientMessageId: 'c-1',
    });
    expect(result.messageText).toBe('Hello');
  });
});
