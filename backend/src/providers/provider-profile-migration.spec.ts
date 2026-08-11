import { QueryRunner } from 'typeorm';
import { ProviderProfiles1720000006000 } from '../../migrations/1720000006000-ProviderProfiles';

describe('ProviderProfiles1720000006000', () => {
  const query = jest.fn<Promise<unknown>, [string]>();
  const queryRunner = { query } as unknown as QueryRunner;
  const migration = new ProviderProfiles1720000006000();

  beforeEach(() => query.mockResolvedValue(undefined));

  it('creates owner uniqueness, coordinate bounds, radius bounds, and cascade ownership', async () => {
    await migration.up(queryRunner);

    const sql = query.mock.calls.map(([statement]) => statement).join('\n');
    expect(sql).toContain('UQ_provider_profiles_user_id');
    expect(sql).toContain('CHK_provider_profiles_radius');
    expect(sql).toContain('CHK_provider_profiles_latitude');
    expect(sql).toContain('CHK_provider_profiles_longitude');
    expect(sql).toContain('ON DELETE CASCADE');
  });

  it('drops the provider profile table on rollback', async () => {
    await migration.down(queryRunner);

    expect(query).toHaveBeenCalledWith('DROP TABLE "provider_profiles"');
  });
});
