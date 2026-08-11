import { QueryRunner } from 'typeorm';
import { ProviderVerification1720000008000 } from '../../../migrations/1720000008000-ProviderVerification';

describe('ProviderVerification1720000008000', () => {
  const query = jest.fn<Promise<unknown>, [string]>();
  const runner = { query } as unknown as QueryRunner;
  beforeEach(() => {
    query.mockReset();
    query.mockResolvedValue(undefined);
  });
  it('adds states, concurrency version, assignment, and immutable events', async () => {
    await new ProviderVerification1720000008000().up(runner);
    const sql = query.mock.calls.flat().join('\n');
    expect(sql).toContain('resubmission_requested');
    expect(sql).toContain('assigned_reviewer_user_id');
    expect(sql).toContain('version');
    expect(sql).toContain('ON DELETE RESTRICT');
  });
  it('drops dependent structures first', async () => {
    await new ProviderVerification1720000008000().down(runner);
    expect(query.mock.calls[0][0]).toContain('provider_verification_events');
  });
});
