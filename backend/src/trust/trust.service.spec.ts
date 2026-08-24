import { TrustService } from './trust.service';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';

describe('TrustService', () => {
  const providerId = '00000000-0000-4000-8000-000000000002';
  const now = new Date('2026-08-21T00:00:00.000Z');
  const bookings = { find: jest.fn(), count: jest.fn() };
  const reviews = { find: jest.fn() };
  const complaints = { count: jest.fn() };
  const signals = {
    findOneBy: jest.fn(),
    create: jest.fn<unknown, [unknown]>((value) => value),
    save: jest.fn((value) => Promise.resolve(value)),
    find: jest.fn(),
    findOneByOrFail: jest.fn(),
  };
  const cache = { get: jest.fn(), set: jest.fn() };
  const service = new TrustService(
    bookings as never,
    reviews as never,
    complaints as never,
    signals as never,
    cache as never,
  );

  beforeEach(() => jest.clearAllMocks());

  it('calculates transparent metrics without fabricating zero-data rates', async () => {
    bookings.find.mockResolvedValue([
      { status: BookingStatus.COMPLETED },
      { status: BookingStatus.CANCELLED },
    ]);
    reviews.find.mockResolvedValue([{ rating: 5 }, { rating: 4 }]);
    complaints.count.mockResolvedValue(2);
    await expect(service.providerMetrics(providerId)).resolves.toEqual({
      completedBookingCount: 1,
      cancelledBookingCount: 1,
      completionRate: 50,
      averageRating: 4.5,
      reviewCount: 2,
      complaintCount: 2,
    });
  });

  it('emits one low-severity advisory signal at the exact cancellation threshold and deduplicates it', async () => {
    bookings.count.mockResolvedValue(3);
    signals.findOneBy.mockResolvedValue(null);
    await service.evaluateCancellationSignal(providerId, now);
    signals.findOneBy.mockResolvedValue({ id: 'signal' });
    await service.evaluateCancellationSignal(providerId, now);
    expect(signals.save).toHaveBeenCalledTimes(1);
    expect(signals.create).toHaveBeenCalledWith(
      expect.objectContaining({ subjectId: providerId, severity: 'LOW' }),
    );
  });

  it.each([0, 1, 2])(
    'does not flag normal cancellation count %s',
    async (count) => {
      bookings.count.mockResolvedValue(count);
      await expect(
        service.evaluateCancellationSignal(providerId, now),
      ).resolves.toBeNull();
      expect(signals.save).not.toHaveBeenCalled();
    },
  );

  describe('providerAcceptTime', () => {
    const accepted = (minutesAgo: number, latencyMinutes: number) => ({
      createdAt: new Date(now.getTime() - minutesAgo * 60_000),
      assignedAt: new Date(
        now.getTime() - (minutesAgo - latencyMinutes) * 60_000,
      ),
    });

    it('computes the explainable rolling mean over bounded samples', async () => {
      bookings.find.mockResolvedValue([
        accepted(600, 30),
        accepted(500, 20),
        accepted(400, 10),
        accepted(300, 25),
      ]);
      await expect(
        service.providerAcceptTime(providerId, now),
      ).resolves.toEqual({
        averageAcceptMinutes: 21,
        sampleSize: 4,
        windowDays: 90,
      });
    });

    it.each([0, 1, 2])(
      'hides the signal below the minimum sample size (%s samples)',
      async (samples) => {
        bookings.find.mockResolvedValue(
          Array.from({ length: samples }, (_, index) =>
            accepted(600 - index, 15),
          ),
        );
        await expect(
          service.providerAcceptTime(providerId, now),
        ).resolves.toEqual({
          averageAcceptMinutes: null,
          sampleSize: samples,
          windowDays: 90,
        });
      },
    );

    it('serves a fresh aggregate when the cache read fails', async () => {
      cache.get.mockRejectedValue(new Error('redis down'));
      bookings.find.mockResolvedValue([
        accepted(600, 10),
        accepted(500, 10),
        accepted(400, 10),
      ]);
      await expect(
        service.providerAcceptTime(providerId, now),
      ).resolves.toEqual({
        averageAcceptMinutes: 10,
        sampleSize: 3,
        windowDays: 90,
      });
      expect(cache.set).toHaveBeenCalled();
    });

    it('short-circuits on a cached aggregate without touching bookings', async () => {
      cache.get.mockResolvedValue({
        averageAcceptMinutes: 12,
        sampleSize: 9,
        windowDays: 90,
      });
      await expect(
        service.providerAcceptTime(providerId, now),
      ).resolves.toEqual({
        averageAcceptMinutes: 12,
        sampleSize: 9,
        windowDays: 90,
      });
      expect(bookings.find).not.toHaveBeenCalled();
    });
  });
});
