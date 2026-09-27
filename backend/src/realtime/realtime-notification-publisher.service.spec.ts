import { RealtimeNotificationPublisher } from './realtime-notification-publisher.service';

describe('RealtimeNotificationPublisher', () => {
  it('publishes account notifications only to subscribed account clients', async () => {
    const subscribedClient = { readyState: 1, send: jest.fn() };
    const otherClient = { readyState: 1, send: jest.fn() };
    const registry = {
      entries: () => [
        [
          subscribedClient,
          {
            principal: { userId: 'user-1' },
            subscriptions: new Map([
              ['subscription-1', { channel: 'account', resourceId: 'user-1' }],
            ]),
          },
        ],
        [
          otherClient,
          {
            principal: { userId: 'user-2' },
            subscriptions: new Map([
              ['subscription-2', { channel: 'account', resourceId: 'user-2' }],
            ]),
          },
        ],
      ],
    };
    const config = { get: jest.fn().mockReturnValue(undefined) };
    const publisher = new RealtimeNotificationPublisher(
      registry as never,
      config as never,
    );

    await publisher.publishAccountNotification('user-1', {
      id: 'notification-1',
      title: 'Booking update',
    });

    expect(subscribedClient.send).toHaveBeenCalledWith(
      JSON.stringify({
        type: 'notification.created.v1',
        data: { id: 'notification-1', title: 'Booking update' },
      }),
    );
    expect(otherClient.send).not.toHaveBeenCalled();
  });
});
