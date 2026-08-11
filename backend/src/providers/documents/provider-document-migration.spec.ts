import { QueryRunner } from 'typeorm';
import { ProviderDocuments1720000007000 } from '../../../migrations/1720000007000-ProviderDocuments';

describe('ProviderDocuments1720000007000', () => {
  const query = jest.fn<Promise<unknown>, [string]>();
  const runner = { query } as unknown as QueryRunner;
  beforeEach(() => {
    query.mockReset();
    query.mockResolvedValue(undefined);
  });
  it('creates private metadata and immutable audit tables with bounds', async () => {
    await new ProviderDocuments1720000007000().up(runner);
    const sql = query.mock.calls.flat().join('\n');
    expect(sql).toContain('size_bytes');
    expect(sql).toContain('10485760');
    expect(sql).toContain('ON DELETE RESTRICT');
    expect(sql).not.toContain('public_url');
  });
  it('reverts in dependency order', async () => {
    await new ProviderDocuments1720000007000().down(runner);
    expect(query.mock.calls[0][0]).toContain('audit_events');
    expect(query.mock.calls[1][0]).toContain('provider_documents');
  });
});
