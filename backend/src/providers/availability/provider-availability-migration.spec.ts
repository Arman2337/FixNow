import { QueryRunner } from 'typeorm';
import { ProviderAvailability1720000009000 } from '../../../migrations/1720000009000-ProviderAvailability';

describe('ProviderAvailability1720000009000', () => {
  const query = jest.fn<Promise<unknown>, [string]>();
  const queryRunner = { query } as unknown as QueryRunner;
  const migration = new ProviderAvailability1720000009000();

  beforeEach(() => query.mockResolvedValue(undefined));

  it('creates unique ownership and constrained transient status', async () => {
    await migration.up(queryRunner);

    const sql = query.mock.calls.map(([statement]) => statement).join('\n');
    expect(sql).toContain('UQ_provider_availability_user');
    expect(sql).toContain('CHK_provider_availability_status');
    expect(sql).toContain('CHK_provider_availability_status_expiry');
    expect(sql).toContain('ON DELETE CASCADE');
  });

  it('drops provider availability on rollback', async () => {
    await migration.down(queryRunner);

    expect(query).toHaveBeenCalledWith('DROP TABLE "provider_availability"');
  });
});
