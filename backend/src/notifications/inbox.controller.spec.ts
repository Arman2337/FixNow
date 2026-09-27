import { ForbiddenException } from '@nestjs/common';
import { REQUIRED_PERMISSION_KEY } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { InboxController } from './domain/inbox.controller';
import { InAppNotification } from './domain/in-app-notification.entity';

describe('InboxController', () => {
  const userId = '00000000-0000-4000-8000-000000000001';
  const repository = {
    find: jest
      .fn<Promise<Array<Partial<InAppNotification>>>, [unknown]>()
      .mockResolvedValue([
        {
          id: 'notification-1',
          title: 'Booking update',
          body: 'Your booking changed.',
          kind: 'booking',
          bookingId: 'booking-1',
          paymentId: null,
          createdAt: new Date('2026-09-24T10:00:00.000Z'),
          readAt: null,
        },
      ]),
    update: jest
      .fn<Promise<{ affected: number }>, [unknown, { readAt: Date }]>()
      .mockResolvedValue({ affected: 1 }),
  };
  const request = {
    authorizationPrincipal: { userId },
  } as never;
  const controller = new InboxController(repository as never);
  const prototypeHandler = (methodName: 'getInbox' | 'markRead'): object => {
    const descriptor = Object.getOwnPropertyDescriptor(
      InboxController.prototype,
      methodName,
    );
    if (!descriptor)
      throw new Error(`Missing controller method: ${methodName}`);
    const handler = descriptor.value as (...args: unknown[]) => unknown;
    return handler;
  };

  it('requires the authenticated user inbox permission', () => {
    expect(
      Reflect.getMetadata(
        REQUIRED_PERMISSION_KEY,
        prototypeHandler('getInbox'),
      ),
    ).toBe(PERMISSIONS.notificationInboxReadSelf);
    expect(
      Reflect.getMetadata(
        REQUIRED_PERMISSION_KEY,
        prototypeHandler('markRead'),
      ),
    ).toBe(PERMISSIONS.notificationInboxReadSelf);
  });

  it('returns notifications for the authenticated user', async () => {
    await expect(controller.getInbox('me', request)).resolves.toEqual([
      expect.objectContaining({
        id: 'notification-1',
        category: 'booking',
        isRead: false,
      }),
    ]);
    expect(repository.find).toHaveBeenCalledWith({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  });

  it('does not allow a user to read another user inbox', async () => {
    await expect(
      controller.getInbox('00000000-0000-4000-8000-000000000002', request),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('marks only the authenticated user notification as read', async () => {
    await expect(
      controller.markRead('me', 'notification-1', request),
    ).resolves.toEqual({ success: true });
    const [updateCriteria, updateValues] =
      repository.update.mock.calls[0] ?? [];
    expect(updateCriteria).toEqual({ id: 'notification-1', userId });
    expect(updateValues.readAt).toBeInstanceOf(Date);
  });

  it('does not allow a user to mark another user notification as read', async () => {
    await expect(
      controller.markRead(
        '00000000-0000-4000-8000-000000000002',
        'notification-1',
        request,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});

void InAppNotification;
