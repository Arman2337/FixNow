import { QueryRunner } from 'typeorm';
import { AuthTokenLifecycle1720000003000 } from '../../migrations/1720000003000-AuthTokenLifecycle';

describe('AuthTokenLifecycle migration', () => {
  it('stores only token/code hashes and rolls back in dependency order', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const runner = { query } as unknown as QueryRunner;
    const migration = new AuthTokenLifecycle1720000003000();

    await migration.up(runner);
    const upSql = query.mock.calls.map(([sql]) => String(sql)).join('\n');
    expect(upSql).toContain('refresh_token_hash');
    expect(upSql).toContain('code_hash');
    expect(upSql).not.toContain('refresh_token"');
    expect(upSql).not.toContain('"code"');

    query.mockClear();
    await migration.down(runner);
    expect(query.mock.calls.map(([sql]) => String(sql))).toEqual([
      'DROP TABLE "auth_audit_events"',
      'DROP TABLE "otp_challenges"',
      'DROP TABLE "auth_sessions"',
    ]);
  });
});
