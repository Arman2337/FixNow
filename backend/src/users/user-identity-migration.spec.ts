import { QueryRunner } from 'typeorm';
import { UserIdentityModel1720000000000 } from '../../migrations/1720000000000-UserIdentityModel';

describe('UserIdentityModel migration', () => {
  it('creates constrained identity tables and rolls them back in dependency order', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const runner = { query } as unknown as QueryRunner;
    const migration = new UserIdentityModel1720000000000();

    await migration.up(runner);
    const upSql = query.mock.calls.map(([sql]) => String(sql)).join('\n');
    expect(upSql).toContain('uq_user_identities_provider_subject');
    expect(upSql).toContain('uq_user_roles_user_role');
    expect(upSql).toContain('ON DELETE CASCADE');

    query.mockClear();
    await migration.down(runner);
    expect(query.mock.calls.map(([sql]) => String(sql))).toEqual([
      'DROP TABLE "user_roles"',
      'DROP TABLE "roles"',
      'DROP TABLE "user_identities"',
      'DROP TABLE "users"',
      'DROP TYPE "account_status"',
    ]);
  });
});
