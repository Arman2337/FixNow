import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { BookingSharesController } from './booking-shares.controller';
import { ShareTokenService } from './share-token.service';

const SECRET = 'a-test-secret';
const tokens = new ShareTokenService({
  get: () => SECRET,
} as unknown as ConfigService);

function booking(overrides: Record<string, unknown> = {}) {
  return {
    id: 'booking-abcdef01-2345',
    customerId: 'customer-1',
    providerId: 'provider-1',
    customerPhone: '+919000000000',
    providerPhone: '+919111111111',
    providerName: 'Suresh Kumar',
    description: 'Customer reports a leak under the kitchen sink',
    locationLat: 17.385,
    locationLng: 78.4867,
    serviceCategoryId: 'cat-1',
    status: BookingStatus.REQUESTED,
    enRouteAt: null,
    createdAt: new Date('2026-10-08T11:00:00.000Z'),
    ...overrides,
  };
}

type Booking = Parameters<BookingsServiceStub['assertParticipant']>[0];
interface BookingsServiceStub {
  assertParticipant: jest.Mock;
  findVisibleForShare: jest.Mock;
}

describe('BookingSharesController (FN-145)', () => {
  const bookings: BookingsServiceStub = {
    assertParticipant: jest.fn().mockResolvedValue(booking()),
    findVisibleForShare: jest.fn().mockResolvedValue(booking()),
  };
  const principal = {
    userId: 'customer-1',
  } as never;
  const request = { authorizationPrincipal: principal } as never;

  const controller = new BookingSharesController(bookings as never, tokens);

  beforeEach(() => {
    jest.clearAllMocks();
    bookings.assertParticipant.mockResolvedValue(booking());
    bookings.findVisibleForShare.mockResolvedValue(booking());
  });

  describe('create', () => {
    it('mints a link only for a participant', async () => {
      const result = await controller.create(request, 'booking-abcdef01-2345');

      expect(bookings.assertParticipant).toHaveBeenCalledWith(
        'booking-abcdef01-2345',
        'customer-1',
        principal,
      );
      expect(tokens.verify(result.token)).toEqual({
        bookingId: 'booking-abcdef01-2345',
      });
      expect(new Date(result.expiresAt).getTime()).toBeGreaterThan(Date.now());
    });

    it('returns nothing that could be read without the token', async () => {
      const result = await controller.create(request, 'booking-abcdef01-2345');

      expect(Object.keys(result).sort()).toEqual(['expiresAt', 'token']);
    });
  });

  describe('view (public)', () => {
    it('answers with a status label and a short opaque reference', async () => {
      const { token } = tokens.mint('booking-abcdef01-2345', 3600);

      const view = await controller.view(token);

      expect(view.reference).toBe('BOOKING-');
      expect(view.status).toBe(BookingStatus.REQUESTED);
      expect(view.statusLabel).toBe('Finding a pro nearby');
      expect(view.arrivingInMinutes).toBeNull();
    });

    it('discloses no customer, provider, address or location', async () => {
      const { token } = tokens.mint('booking-abcdef01-2345', 3600);

      const view = (await controller.view(token)) as Record<string, unknown>;

      // The strongest assertion available: nothing from the entity that could
      // identify anybody or place anybody may appear at all.
      const serialised = JSON.stringify(view);
      for (const secret of [
        'customer-1',
        'provider-1',
        'Suresh Kumar',
        '919000000000',
        '91111111111',
        'kitchen sink',
        '17.385',
        '78.4867',
        'cat-1',
        'locationLat',
        'locationLng',
      ]) {
        expect(serialised).not.toContain(secret);
      }
      expect(Object.keys(view).sort()).toEqual([
        'arrivingInMinutes',
        'reference',
        'status',
        'statusLabel',
        'updatedAt',
      ]);
    });

    it('buckets the arrival estimate rather than counting down', async () => {
      bookings.findVisibleForShare.mockResolvedValue(
        booking({ status: BookingStatus.EN_ROUTE, enRouteAt: new Date() }),
      );
      const { token } = tokens.mint('booking-abcdef01-2345', 3600);

      const view = await controller.view(token);

      expect(view.statusLabel).toBe('On the way to you');
      expect(view.arrivingInMinutes).toBe(0);
    });

    it('withholds an estimate once it is no longer meaningful', async () => {
      bookings.findVisibleForShare.mockResolvedValue(
        booking({
          status: BookingStatus.EN_ROUTE,
          enRouteAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
        }),
      );
      const { token } = tokens.mint('booking-abcdef01-2345', 3600);

      expect((await controller.view(token)).arrivingInMinutes).toBeNull();
    });

    it('refuses a bad token before touching the database', async () => {
      await expect(controller.view('not-a-token')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(bookings.findVisibleForShare).not.toHaveBeenCalled();
    });

    it('gives a deleted booking the same answer as a bad token', async () => {
      // Otherwise the endpoint is a booking-existence oracle: valid token,
      // unknown job, and the caller learns a job id once existed.
      bookings.findVisibleForShare.mockResolvedValue(null);
      const { token } = tokens.mint('booking-abcdef01-2345', 3600);

      await expect(controller.view(token)).rejects.toThrow(
        /invalid or has expired/,
      );
      await expect(controller.view('not-a-token')).rejects.toThrow(
        /invalid or has expired/,
      );
    });
  });
});
