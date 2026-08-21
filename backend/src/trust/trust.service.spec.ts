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
  const service = new TrustService(
    bookings as never,
    reviews as never,
    complaints as never,
    signals as never,
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
});
