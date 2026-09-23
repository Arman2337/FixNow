import { QueryRunner } from 'typeorm';
import { BookingLineItems1786521300000 } from '../../migrations/1786521300000-BookingLineItems';

describe('BookingLineItems1786521300000', () => {
  const query = jest.fn<Promise<unknown>, [string]>();
  const runner = { query } as unknown as QueryRunner;

  beforeEach(() => query.mockResolvedValue(undefined));

  it('adds the item snapshot, total, and duration columns to bookings', async () => {
    await new BookingLineItems1786521300000().up(runner);
    const sql = query.mock.calls.map(([statement]) => statement).join('\n');
    expect(sql).toContain('"items" jsonb');
    expect(sql).toContain('"total_amount_minor" integer');
    expect(sql).toContain('"estimated_duration_minutes" integer');
  });

  it('drops the columns on down', async () => {
    await new BookingLineItems1786521300000().down(runner);
    const sql = query.mock.calls.map(([statement]) => statement).join('\n');
    expect(sql).toContain('DROP COLUMN "items"');
    expect(sql).toContain('DROP COLUMN "total_amount_minor"');
    expect(sql).toContain('DROP COLUMN "estimated_duration_minutes"');
  });
});
