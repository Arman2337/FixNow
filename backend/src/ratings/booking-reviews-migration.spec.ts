import { QueryRunner } from 'typeorm';
import { BookingReviews1786520000000 } from '../../migrations/1786520000000-BookingReviews';

describe('BookingReviews1786520000000', () => {
  const query = jest.fn<Promise<unknown>, [string]>();
  const runner = { query } as unknown as QueryRunner;

  beforeEach(() => query.mockResolvedValue(undefined));

  it('enforces one review per booking, bounded rating, and publication-aware aggregation', async () => {
    await new BookingReviews1786520000000().up(runner);
    const sql = query.mock.calls.map(([statement]) => statement).join('\n');
    expect(sql).toContain('UQ_booking_reviews_booking');
    expect(sql).toContain('CHK_booking_reviews_rating');
    expect(sql).toContain('IDX_booking_reviews_provider_published');
  });
});
