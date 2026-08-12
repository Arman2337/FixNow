import { ForbiddenException, ConflictException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { ProviderAvailabilityStatus } from '../../../shared/provider-availability.types';
import { Booking } from '../bookings/domain/booking.entity';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import { ProviderAvailabilityEntity } from '../providers/availability/provider-availability.entity';
import { LocationService } from './location.service';

const PROVIDER_ID = '00000000-0000-4000-8000-000000000001';
const OTHER_PROVIDER_ID = '00000000-0000-4000-8000-000000000002';
const BOOKING_ID = '00000000-0000-4000-8000-000000000010';
const NOW = new Date('2026-08-13T12:00:00.000Z');

describe('LocationService', () => {
  let service: LocationService;
  let cacheValues: Map<string, unknown>;
  let cache: { get: jest.Mock; set: jest.Mock; del: jest.Mock };
  let booking: Partial<Booking>;
  let availability: Partial<ProviderAvailabilityEntity>;
  let bookingRepository: { findOne: jest.Mock; find: jest.Mock };
  let availabilityRepository: { findOne: jest.Mock };

  const provider: AuthorizationPrincipal = {
    userId: PROVIDER_ID,
    sessionId: '00000000-0000-4000-8000-000000000020',
    roles: ['verified_provider'],
  };

  beforeEach(() => {
    cacheValues = new Map();
    cache = {
      get: jest.fn((key: string) => Promise.resolve(cacheValues.get(key))),
      set: jest.fn((key: string, value: unknown) => {
        cacheValues.set(key, value);
        return Promise.resolve(value);
      }),
      del: jest.fn((key: string) => {
        cacheValues.delete(key);
        return Promise.resolve(true);
      }),
    };
    booking = {
      id: BOOKING_ID,
      providerId: PROVIDER_ID,
      status: BookingStatus.EN_ROUTE,
    };
    availability = {
      userId: PROVIDER_ID,
      status: ProviderAvailabilityStatus.Online,
      statusExpiresAt: new Date(NOW.getTime() + 60_000),
    };
    bookingRepository = {
      findOne: jest.fn(() => Promise.resolve(booking)),
      find: jest.fn(() => Promise.resolve([{ id: BOOKING_ID }])),
    };
    availabilityRepository = {
      findOne: jest.fn(() => Promise.resolve(availability)),
    };
    const dataSource = {
      getRepository: jest.fn((entity: unknown) =>
        entity === Booking ? bookingRepository : availabilityRepository,
      ),
    };
    const config = new ConfigService({
      LOCATION_UPDATE_INTERVAL_MS: 10_000,
      LOCATION_STALE_AFTER_MS: 60_000,
      LOCATION_CACHE_TTL_MS: 60_000,
      LOCATION_PRESENCE_TTL_MS: 45_000,
      LOCATION_CONSENT_TTL_MS: 43_200_000,
      LOCATION_MAX_ACCURACY_METERS: 100,
      LOCATION_NOTICE_VERSION: '2026-08-13',
    });
    service = new LocationService(dataSource as never, cache as never, config);
  });

  it('requires a verified provider and current online availability for presence', async () => {
    await expect(
      service.updatePresence(
        { ...provider, roles: ['customer'] },
        { online: true },
        NOW,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    availability.status = ProviderAvailabilityStatus.Offline;
    await expect(
      service.updatePresence(provider, { online: true }, NOW),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('creates a bounded presence lease and invalidates location when going offline', async () => {
    await expect(
      service.updatePresence(provider, { online: true }, NOW),
    ).resolves.toEqual({
      online: true,
      expiresAt: '2026-08-13T12:00:45.000Z',
    });
    expect(cache.set).toHaveBeenCalledWith(
      expect.stringContaining(':presence:'),
      expect.any(Object),
      45_000,
    );
    cacheValues.set(`location:v1:latest:${BOOKING_ID}`, { sequence: 1 });
    cacheValues.set(`location:v1:consent:${BOOKING_ID}`, { granted: true });
    await service.updatePresence(provider, { online: false }, NOW);
    expect(cacheValues.has(`location:v1:latest:${BOOKING_ID}`)).toBe(false);
    expect(cacheValues.has(`location:v1:consent:${BOOKING_ID}`)).toBe(false);
  });

  it('requires explicit current notice consent and immediately deletes location on revocation', async () => {
    await expect(
      service.updateConsent(
        provider,
        { bookingId: BOOKING_ID, granted: true, noticeVersion: 'old' },
        NOW,
      ),
    ).rejects.toBeTruthy();
    await service.updateConsent(
      provider,
      { bookingId: BOOKING_ID, granted: true, noticeVersion: '2026-08-13' },
      NOW,
    );
    expect(cacheValues.has(`location:v1:consent:${BOOKING_ID}`)).toBe(true);
    cacheValues.set(`location:v1:latest:${BOOKING_ID}`, { sequence: 1 });
    await service.updateConsent(
      provider,
      { bookingId: BOOKING_ID, granted: false, noticeVersion: '2026-08-13' },
      NOW,
    );
    expect(cacheValues.has(`location:v1:latest:${BOOKING_ID}`)).toBe(false);
  });

  it('rejects stale coordinates and location from a provider who does not own the booking', async () => {
    seedAuthorization();
    await expect(
      service.ingestLocation(
        provider,
        location({ capturedAt: '2026-08-13T11:58:59.999Z' }),
        NOW,
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    booking.providerId = OTHER_PROVIDER_ID;
    await expect(
      service.ingestLocation(provider, location(), NOW),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('requires current presence and consent before accepting precise location', async () => {
    await expect(
      service.ingestLocation(provider, location(), NOW),
    ).rejects.toBeInstanceOf(ForbiddenException);
    cacheValues.set(`location:v1:presence:${PROVIDER_ID}`, { online: true });
    await expect(
      service.ingestLocation(provider, location(), NOW),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rate limits and rejects non-monotonic updates', async () => {
    seedAuthorization();
    await service.ingestLocation(provider, location({ sequence: 2 }), NOW);
    await expect(
      service.ingestLocation(
        provider,
        location({ sequence: 3 }),
        new Date(NOW.getTime() + 9_999),
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    await expect(
      service.ingestLocation(
        provider,
        location({ sequence: 2 }),
        new Date(NOW.getTime() + 10_000),
      ),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('retains only the latest point with the configured 60-second TTL', async () => {
    seedAuthorization();
    await expect(
      service.ingestLocation(provider, location(), NOW),
    ).resolves.toEqual({
      sequence: 1,
      receivedAt: NOW.toISOString(),
      staleAt: '2026-08-13T12:01:00.000Z',
    });
    expect(cache.set).toHaveBeenLastCalledWith(
      `location:v1:latest:${BOOKING_ID}`,
      expect.objectContaining({
        bookingId: BOOKING_ID,
        providerId: PROVIDER_ID,
        sequence: 1,
      }),
      60_000,
    );
    expect(bookingRepository.findOne).toHaveBeenCalledTimes(1);
  });

  function seedAuthorization(): void {
    cacheValues.set(`location:v1:presence:${PROVIDER_ID}`, { online: true });
    cacheValues.set(`location:v1:consent:${BOOKING_ID}`, { granted: true });
  }

  function location(overrides: Record<string, unknown> = {}) {
    return {
      bookingId: BOOKING_ID,
      sequence: 1,
      capturedAt: NOW.toISOString(),
      latitude: 22.3072,
      longitude: 73.1812,
      accuracyMeters: 18,
      ...overrides,
    };
  }
});
