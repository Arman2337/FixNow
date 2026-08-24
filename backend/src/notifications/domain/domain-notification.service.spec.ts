import { Repository } from 'typeorm';
import { BookingStatus } from '../../../../shared/booking-lifecycle.types';
import { Booking } from '../../bookings/domain/booking.entity';
import { PushDeviceTokenEntity } from '../push/push-device-token.entity';
import {
  BOOKING_NOTIFICATION_TEMPLATES,
  DomainNotificationService,
} from './domain-notification.service';
import {
  NotificationDelivery,
  NotificationDeliveryStatus,
} from './notification-delivery.entity';

describe('DomainNotificationService', () => {
  const userId = '00000000-0000-4000-8000-0000000000aa';
  const booking = {
    id: 'bbbbbbbb-0000-4000-8000-0000000000bb',
    customerId: userId,
    providerId: '00000000-0000-4000-8000-0000000000cc',
  } as Booking;

  const deliveries = {
    findOneBy: jest.fn().mockResolvedValue(null),
    insert: jest.fn().mockResolvedValue(undefined),
    create: jest.fn(<T extends object>(value: T): T => value),
  };
  const devices = {
    find: jest.fn().mockResolvedValue([{ token: 'device-token-1' }]),
    update: jest.fn().mockResolvedValue(undefined),
  };
  const delivery = {
    sendToToken: jest.fn().mockResolvedValue({ status: 'sent' }),
  };
  const service = new DomainNotificationService(
    deliveries as unknown as Repository<NotificationDelivery>,
    devices as unknown as Repository<PushDeviceTokenEntity>,
    delivery,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    deliveries.findOneBy.mockResolvedValue(null);
    devices.find.mockResolvedValue([{ token: 'device-token-1' }]);
    delivery.sendToToken.mockResolvedValue({ status: 'sent' });
    delete process.env.NOTIFICATION_QUIET_HOURS_UTC;
  });
  afterEach(() => delete process.env.NOTIFICATION_QUIET_HOURS_UTC);

  it('maps booking transitions to lock-screen-safe templates without personal data', async () => {
    await service.notifyBookingEvent(
      booking,
      'customer',
      BookingStatus.ASSIGNED,
    );
    expect(delivery.sendToToken).toHaveBeenCalledTimes(1);
    const [sentToken, content] = delivery.sendToToken.mock
      .calls[0] as unknown as [string, { title: string; body: string }];
    expect(sentToken).toBe('device-token-1');
    expect(content.title).toBe('FixNow');
    expect(content.body).not.toContain(booking.customerId);
    expect(BOOKING_NOTIFICATION_TEMPLATES['customer:ASSIGNED']).toBeDefined();
  });

  it('deduplicates replays through the delivery record', async () => {
    deliveries.findOneBy.mockResolvedValue({ id: 'existing' });
    await service.notifyBookingEvent(
      booking,
      'customer',
      BookingStatus.ASSIGNED,
    );
    expect(delivery.sendToToken).not.toHaveBeenCalled();
    expect(deliveries.insert).not.toHaveBeenCalled();
  });

  it('records NO_DEVICES without sending when nothing is enrolled', async () => {
    devices.find.mockResolvedValue([]);
    await service.notifyBookingEvent(
      booking,
      'customer',
      BookingStatus.COMPLETED,
    );
    expect(delivery.sendToToken).not.toHaveBeenCalled();
    expect(deliveries.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        status: NotificationDeliveryStatus.NO_DEVICES,
        dedupeKey: `booking:${booking.id}:customer:COMPLETED`,
      }),
    );
  });

  it('disables unregistered tokens and records the attempt', async () => {
    delivery.sendToToken.mockResolvedValue({ status: 'unregistered' });
    await service.notifyBookingEvent(
      booking,
      'customer',
      BookingStatus.EN_ROUTE,
    );
    expect(devices.update).toHaveBeenCalledWith(
      { token: 'device-token-1' },
      { enabled: false },
    );
    expect(deliveries.insert).toHaveBeenCalledWith(
      expect.objectContaining({ status: NotificationDeliveryStatus.FAILED }),
    );
  });

  it.each(['22-7', '23-6'])(
    'skips delivery inside the configured quiet hours (%s)',
    async (window) => {
      process.env.NOTIFICATION_QUIET_HOURS_UTC = window;
      const hour = new Date().getUTCHours();
      const inWindow =
        window === '22-7' ? hour >= 22 || hour < 7 : hour >= 23 || hour < 6;
      if (!inWindow) return; // deterministic only inside the window
      await service.notifyBookingEvent(
        booking,
        'customer',
        BookingStatus.ASSIGNED,
      );
      expect(delivery.sendToToken).not.toHaveBeenCalled();
      expect(deliveries.insert).toHaveBeenCalledWith(
        expect.objectContaining({
          status: NotificationDeliveryStatus.SKIPPED_QUIET_HOURS,
        }),
      );
    },
  );

  it('caps the provider fan-out for a new request', async () => {
    const many = Array.from({ length: 30 }, (_, i) => `provider-${i}`);
    await service.notifyProvidersOfAvailableRequest(booking, many, 20);
    expect(delivery.sendToToken).toHaveBeenCalledTimes(20);
    expect(deliveries.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        dedupeKey: `booking:${booking.id}:provider:REQUESTED`,
      }),
    );
  });

  it('swallows a lost dedupe race on concurrent inserts', async () => {
    deliveries.insert.mockRejectedValueOnce(new Error('duplicate key'));
    await expect(
      service.send(userId, 'kind', 'dedupe-key', {
        title: 'FixNow',
        body: 'b',
      }),
    ).resolves.toBeUndefined();
  });
});
