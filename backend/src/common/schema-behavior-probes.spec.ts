import type { DataSource } from 'typeorm';
import { verifySchemaBehavior } from '../../scripts/schema-behavior-probes';

describe('Schema behavioral probes on an empty database', () => {
  const harness = () => {
    const query = jest.fn().mockImplementation((sql: string) => {
      if (sql.includes('gate-orphan'))
        return Promise.reject(
          Object.assign(new Error('foreign key'), { code: '23503' }),
        );
      if (
        sql.includes('gate-neg') ||
        sql.includes('gate-lat') ||
        sql.includes('gate-stage-check') ||
        sql.includes('gate-size-check')
      )
        return Promise.reject(
          Object.assign(new Error('check'), { code: '23514' }),
        );
      if (sql.includes('gate-unique-b'))
        return Promise.reject(
          Object.assign(new Error('unique'), { code: '23505' }),
        );
      if (sql.startsWith('INSERT INTO users'))
        return Promise.resolve([{ id: 'temporary-user' }]);
      if (sql.includes('INSERT INTO service_categories'))
        return Promise.resolve([{ id: 'temporary-category' }]);
      if (sql.includes('RETURNING id, version'))
        return Promise.resolve([{ id: 'temporary-booking', version: 1 }]);
      if (sql.includes('RETURNING id AS b'))
        return Promise.resolve([{ b: 'temporary-proof-booking' }]);
      return Promise.resolve([]);
    });
    const runner = {
      connect: jest.fn(),
      startTransaction: jest.fn(),
      rollbackTransaction: jest.fn(),
      release: jest.fn(),
      query,
    };
    const ds = {
      createQueryRunner: jest.fn().mockReturnValue(runner),
    } as unknown as DataSource;
    return { ds, runner, query };
  };

  it('runs every invariant without seed data and rolls back only its own temporary fixtures', async () => {
    const { ds, runner, query } = harness();
    const check = jest.fn();
    await verifySchemaBehavior(ds, { check });
    expect(check).toHaveBeenCalledTimes(8);
    for (const [passed] of check.mock.calls) expect(passed).toBe(true);
    const sql = query.mock.calls
      .map(([statement]) => String(statement))
      .join('\n');
    expect(sql).not.toMatch(
      /SELECT id (AS b )?FROM bookings|SELECT id FROM users|SELECT id FROM service_categories/,
    );
    expect(sql).toContain('INSERT INTO users DEFAULT VALUES');
    expect(sql).toContain('INSERT INTO service_categories');
    expect(sql).toContain('SAVEPOINT schema_probe');
    expect(runner.rollbackTransaction).toHaveBeenCalledTimes(1);
    expect(runner.release).toHaveBeenCalledTimes(1);
  });

  it('rolls back and releases the connection if temporary fixture creation fails', async () => {
    const { ds, runner, query } = harness();
    const ordinaryQuery = query.getMockImplementation()!;
    query.mockImplementation((sql: string) =>
      sql.startsWith('INSERT INTO users')
        ? Promise.reject(new Error('fixture failure'))
        : ordinaryQuery(sql),
    );
    await expect(
      verifySchemaBehavior(ds, { check: jest.fn() }),
    ).rejects.toThrow('fixture failure');
    expect(runner.rollbackTransaction).toHaveBeenCalledTimes(1);
    expect(runner.release).toHaveBeenCalledTimes(1);
  });
});
