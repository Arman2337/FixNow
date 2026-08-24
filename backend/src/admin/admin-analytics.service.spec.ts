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
  const service = new AdminAnalyticsService(bookings, applications, services);

  beforeEach(() => {
    jest.clearAllMocks();
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
});
