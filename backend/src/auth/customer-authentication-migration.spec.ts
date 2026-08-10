import { QueryRunner } from 'typeorm';
import { CustomerAuthentication1720000001000 } from '../../migrations/1720000001000-CustomerAuthentication';

describe('CustomerAuthentication migration', () => {
  it('creates credential storage, seeds the customer role, and rolls back safely', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const runner = { query } as unknown as QueryRunner;
    const migration = new CustomerAuthentication1720000001000();

    await migration.up(runner);
    const upSql = query.mock.calls.map(([sql]) => String(sql)).join('\n');
    expect(upSql).toContain('auth_credentials');
    expect(upSql).toContain('password_hash');
    expect(upSql).toContain('ON DELETE CASCADE');
    expect(upSql).toContain("'customer'");
    expect(upSql).not.toContain('password123');

    query.mockClear();
    await migration.down(runner);
    expect(query.mock.calls.map(([sql]) => String(sql))).toEqual([
      expect.stringContaining('DELETE FROM "roles"'),
      'DROP TABLE "auth_credentials"',
    ]);
  });
});
