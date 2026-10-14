import { DataSource, Repository } from 'typeorm';
import { BookingDispatchHandlers } from './booking-dispatch.handlers';
import { Booking } from './domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { OutboxService, OutboxWorker } from '../outbox/outbox.service';
import { BookingsService } from './bookings.service';
import { MatchingService } from '../matching/matching.service';
import { DomainNotificationService } from '../notifications/domain/domain-notification.service';
import { BookingProjectionService } from '../realtime/booking-projection.service';
import { OutboxMessage } from '../outbox/outbox-message.entity';

describe('BookingDispatchHandlers', () => {
  let handlers: BookingDispatchHandlers;
  let dataSource: jest.Mocked<DataSource>;
  let bookingRepo: jest.Mocked<Repository<Booking>>;
  let worker: jest.Mocked<OutboxWorker>;
  let outbox: jest.Mocked<OutboxService>;
  let bookings: jest.Mocked<BookingsService>;
  let matching: jest.Mocked<MatchingService>;
  let notifications: jest.Mocked<DomainNotificationService>;
  let projections: jest.Mocked<BookingProjectionService>;
  const registeredHandlers = new Map<string, (msg: any) => Promise<void>>();

  const bookingId = '00000000-0000-4000-8000-000000000001';

  const mockBooking = (
    status = BookingStatus.REQUESTED,
    overrides = {},
  ): Booking =>
    Object.assign(new Booking(), {
      id: bookingId,
      customerId: 'cust-1',
      serviceCategoryId: 'cat-plumbing',
      locationLat: 12.9716,
      locationLng: 77.5946,
      status,
      version: 1,
      deletedAt: null,
      ...overrides,
    });

  beforeEach(() => {
    registeredHandlers.clear();

    bookingRepo = {
      findOneBy: jest.fn(),
    } as unknown as jest.Mocked<Repository<Booking>>;

    dataSource = {
      getRepository: jest.fn().mockReturnValue(bookingRepo),
      transaction: jest.fn(),
      manager: {} as any,
    } as unknown as jest.Mocked<DataSource>;

    worker = {
      register: jest.fn((kind: string, handler: any) => {
        registeredHandlers.set(kind, handler);
      }),
    } as unknown as jest.Mocked<OutboxWorker>;

    outbox = {
      enqueue: jest.fn().mockResolvedValue(true),
    } as unknown as jest.Mocked<OutboxService>;

    bookings = {
      expireUnmatchedRequest: jest.fn().mockResolvedValue(undefined),
    } as unknown as jest.Mocked<BookingsService>;

    matching = {
      findEligibleProviders: jest.fn(),
      countEligibleProviders: jest.fn(),
    } as unknown as jest.Mocked<MatchingService>;

    notifications = {
      notifyProvidersOfAvailableRequest: jest.fn().mockResolvedValue(undefined),
    } as unknown as jest.Mocked<DomainNotificationService>;

    projections = {
      publishBooking: jest.fn().mockResolvedValue(undefined),
      publishAccountSignal: jest.fn().mockResolvedValue(undefined),
    } as unknown as jest.Mocked<BookingProjectionService>;

    handlers = new BookingDispatchHandlers(
      dataSource,
      worker,
      outbox,
      bookings,
      matching,
      notifications,
      projections,
    );

    handlers.onModuleInit();
  });

  it('registers handlers for fanout, project, and expiry on init', () => {
    expect(worker.register).toHaveBeenCalledWith(
      'booking.provider-fanout',
      expect.any(Function),
    );
    expect(worker.register).toHaveBeenCalledWith(
      'booking.project',
      expect.any(Function),
    );
    expect(worker.register).toHaveBeenCalledWith(
      'booking.requested-expiry',
      expect.any(Function),
    );
  });

  describe('fanOut', () => {
    it('notifies eligible providers and publishes signals for requested booking', async () => {
      const booking = mockBooking();
      (bookingRepo.findOneBy as jest.Mock).mockResolvedValue(booking);
      (matching.findEligibleProviders as jest.Mock).mockResolvedValue([
        { providerId: 'p1', distanceMeters: 500 },
        { providerId: 'p2', distanceMeters: 1200 },
      ]);

      const fanOutHandler = registeredHandlers.get('booking.provider-fanout')!;
      const msg = Object.assign(new OutboxMessage(), {
        payload: { bookingId },
      });

      await fanOutHandler(msg);

      expect(matching.findEligibleProviders).toHaveBeenCalledWith(
        12.9716,
        77.5946,
        'cat-plumbing',
        expect.any(Number),
      );
      expect(
        notifications.notifyProvidersOfAvailableRequest,
      ).toHaveBeenCalledWith(booking, ['p1', 'p2'], expect.any(Number));
      expect(projections.publishAccountSignal).toHaveBeenCalledTimes(2);
    });

    it('does nothing if booking is no longer in REQUESTED status', async () => {
      const booking = mockBooking(BookingStatus.ASSIGNED);
      (bookingRepo.findOneBy as jest.Mock).mockResolvedValue(booking);

      const fanOutHandler = registeredHandlers.get('booking.provider-fanout')!;
      const msg = Object.assign(new OutboxMessage(), {
        payload: { bookingId },
      });

      await fanOutHandler(msg);

      expect(matching.findEligibleProviders).not.toHaveBeenCalled();
      expect(
        notifications.notifyProvidersOfAvailableRequest,
      ).not.toHaveBeenCalled();
    });
  });

  describe('project', () => {
    it('publishes booking projection when dispatchable', async () => {
      const booking = mockBooking();
      (bookingRepo.findOneBy as jest.Mock).mockResolvedValue(booking);

      const projectHandler = registeredHandlers.get('booking.project')!;
      const msg = Object.assign(new OutboxMessage(), {
        payload: { bookingId },
      });

      await projectHandler(msg);

      expect(projections.publishBooking).toHaveBeenCalledWith(booking);
    });
  });

  describe('expireIfUnmatched', () => {
    it('expires booking when no eligible providers remain', async () => {
      const booking = mockBooking();
      (bookingRepo.findOneBy as jest.Mock).mockResolvedValue(booking);
      (matching.countEligibleProviders as jest.Mock).mockResolvedValue(0);

      const expiryHandler = registeredHandlers.get('booking.requested-expiry')!;
      const msg = Object.assign(new OutboxMessage(), {
        payload: { bookingId },
      });

      await expiryHandler(msg);

      expect(bookings.expireUnmatchedRequest).toHaveBeenCalledWith(
        booking.id,
        booking.version,
      );
    });

    it('re-arms expiry when eligible providers are still available', async () => {
      const booking = mockBooking();
      (bookingRepo.findOneBy as jest.Mock).mockResolvedValue(booking);
      (matching.countEligibleProviders as jest.Mock).mockResolvedValue(2);
      (dataSource.transaction as jest.Mock).mockImplementation(async (cb) => {
        return cb({} as any);
      });

      const expiryHandler = registeredHandlers.get('booking.requested-expiry')!;
      const msg = Object.assign(new OutboxMessage(), {
        payload: { bookingId },
      });

      await expiryHandler(msg);

      expect(bookings.expireUnmatchedRequest).not.toHaveBeenCalled();
      expect(outbox.enqueue).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          kind: 'booking.requested-expiry',
          payload: { bookingId },
        }),
      );
    });
  });
});
