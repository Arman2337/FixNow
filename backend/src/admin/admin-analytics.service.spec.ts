import type { Repository } from 'typeorm';
import { AdminAnalyticsService } from './admin-analytics.service';
import { Booking } from '../bookings/domain/booking.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';

describe('AdminAnalyticsService', () => {
  const bookingQueryBuilder = {
    select: jest.fn().mockReturnThis(),
    addSelect: jest.fn().mockReturnThis(),
    groupBy: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getRawMany: jest.fn(),
    getRawOne: jest.fn(),
    getCount: jest.fn(),
  };
  const bookings = {
    count: jest.fn(),
    createQueryBuilder: jest.fn(),
  } as unknown as Repository<Booking>;
  const applications = {
    count: jest.fn(),
  } as unknown as Repository<ProviderApplicationEntity>;
  const services = {
    findOne: jest.fn(),
    find: jest.fn(),
  } as unknown as Repository<ServiceCategoryEntity>;
  // Untyped on purpose: two versions of cache-manager are present in the tree
  // and the structural cast at the call site is the one the DI token uses.
  const cacheGet = jest.fn();
  const cacheSet = jest.fn();
  const cache = { get: cacheGet, set: cacheSet } as never;
  const service = new AdminAnalyticsService(
    bookings,
    applications,
    services,
    cache,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    cacheGet.mockResolvedValue(undefined);
    cacheSet.mockResolvedValue(undefined);
    (bookings.count as jest.Mock)
      .mockResolvedValueOnce(12)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(6);
    (applications.count as jest.Mock)
      .mockResolvedValueOnce(5)
      .mockResolvedValueOnce(3)
      .mockResolvedValueOnce(2);
    (bookings.createQueryBuilder as jest.Mock).mockReturnValue(
      bookingQueryBuilder,
    );
    bookingQueryBuilder.getRawMany.mockResolvedValue([
      { categoryId: 'priority-service', count: '7' },
    ]);
    bookingQueryBuilder.getCount
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(7);
    (services.findOne as jest.Mock).mockResolvedValue({
      name: 'Priority service',
    });
    (services.find as jest.Mock).mockResolvedValue([
      { id: 'priority-service' },
    ]);
    bookingQueryBuilder.getRawOne.mockResolvedValue({
      sample: '4',
      avgMinutes: '12.5',
    });
  });

  it('returns a timestamped, non-financial operational snapshot', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-08-21T12:00:00.000Z'));

    await expect(service.getOperationalAnalytics()).resolves.toMatchObject({
      generatedAt: '2026-08-21T12:00:00.000Z',
      bookings: { total: 12, completed: 4, cancelled: 2, pending: 6 },
      providers: { total: 5, active: 3, verified: 3, pendingVerification: 2 },
      services: {
        topCategories: [
          { id: 'priority-service', name: 'Priority service', count: 7 },
        ],
      },
      emergencies: { activeRequests: 1, totalRequests: 7 },
      trust: { averageAcceptMinutes: 13, sampleSize: 4, windowDays: 90 },
    });

    jest.useRealTimers();
  });

  it('hides the accept-time signal below the minimum sample size', async () => {
    bookingQueryBuilder.getRawOne.mockResolvedValue({
      sample: '2',
      avgMinutes: '9',
    });
    await expect(service.getOperationalAnalytics()).resolves.toMatchObject({
      trust: { averageAcceptMinutes: null, sampleSize: 2, windowDays: 90 },
    });
  });

  // The audit counted nine sequential aggregate queries per dashboard load.
  // A short-TTL cache is the fix it proposed; this pins that it is consulted.
  it('serves a repeat dashboard load from cache without re-aggregating', async () => {
    const first = await service.getOperationalAnalytics();
    expect(cacheSet).toHaveBeenCalledTimes(1);

    const countsAfterFirst = (bookings.count as jest.Mock).mock.calls.length;
    cacheGet.mockResolvedValue(first);

    const second = await service.getOperationalAnalytics();

    expect(second).toEqual(first);
    expect((bookings.count as jest.Mock).mock.calls).toHaveLength(
      countsAfterFirst,
    );
  });

  it('still computes when the cache read fails', async () => {
    cacheGet.mockRejectedValue(new Error('redis down'));

    await expect(service.getOperationalAnalytics()).resolves.toMatchObject({
      bookings: { total: 12 },
    });
  });

  it('still returns analytics when the cache write fails', async () => {
    cacheSet.mockRejectedValue(new Error('redis down'));

    await expect(service.getOperationalAnalytics()).resolves.toMatchObject({
      bookings: { total: 12 },
    });
  });
});
