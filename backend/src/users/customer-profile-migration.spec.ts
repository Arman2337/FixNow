import { QueryRunner } from 'typeorm';
import { CustomerProfile1720000004000 } from '../../migrations/1720000004000-CustomerProfile';

describe('CustomerProfile migration', () => {
  it('creates a minimal cascade-deleted profile and rolls it back', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const runner = { query } as unknown as QueryRunner;
    const migration = new CustomerProfile1720000004000();

    await migration.up(runner);
    const calls = query.mock.calls as unknown[][];
    const sql = String(calls[0][0]);
    expect(sql).toContain('"display_name" varchar(80) NOT NULL');
    expect(sql).toContain('ON DELETE CASCADE');
    expect(sql).not.toContain('phone');
    expect(sql).not.toContain('address');

    query.mockClear();
    await migration.down(runner);
    expect(query).toHaveBeenCalledWith('DROP TABLE "customer_profiles"');
  });
});
