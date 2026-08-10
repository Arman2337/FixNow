import { QueryRunner } from 'typeorm';
import { ProviderRegistration1720000002000 } from '../../migrations/1720000002000-ProviderRegistration';

describe('ProviderRegistration migration', () => {
  it('creates only the unverified state and rolls back in dependency order', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const runner = { query } as unknown as QueryRunner;
    const migration = new ProviderRegistration1720000002000();

    await migration.up(runner);
    const upSql = query.mock.calls.map(([sql]) => String(sql)).join('\n');
    expect(upSql).toContain("AS ENUM ('unverified')");
    expect(upSql).toContain('provider_applications');
    expect(upSql).toContain("'provider_applicant'");
    expect(upSql).not.toContain("'verified'");

    query.mockClear();
    await migration.down(runner);
    expect(query.mock.calls.map(([sql]) => String(sql))).toEqual([
      'DROP TABLE "provider_applications"',
      expect.stringContaining('DELETE FROM "roles"'),
      'DROP TYPE "provider_onboarding_status"',
    ]);
  });
});
