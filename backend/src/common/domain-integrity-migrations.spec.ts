import { readdirSync } from 'fs';
import { join } from 'path';
import type { QueryRunner } from 'typeorm';
import { RemainingDomainForeignKeys1789750600000 } from '../../migrations/1789750600000-RemainingDomainForeignKeys';

describe('Domain integrity migration safety', () => {
  it('preserves the known applied timestamp collision and forbids new collisions', () => {
    const files = readdirSync(join(__dirname, '../../migrations')).filter(
      (file) => file.endsWith('.ts'),
    );
    const grouped = new Map<string, string[]>();
    for (const file of files) {
      const timestamp = file.split('-')[0];
      grouped.set(timestamp, [...(grouped.get(timestamp) ?? []), file]);
    }
    const collisions = [...grouped.values()].filter(
      (group) => group.length > 1,
    );
    expect(collisions).toHaveLength(1);
    expect(collisions[0].sort()).toEqual([
      '1786521300000-BookingLineItems.ts',
      '1786521300000-ComplaintsSchema.ts',
    ]);
    // TypeORM uses timestamp ordering; neither historic migration depends on
    // the other's tables. Pin their names rather than rename applied history.
  });

  it('adds indexed references without deleting legacy rows or auditing history', async () => {
    const query = jest.fn().mockResolvedValue([]);
    const migration = new RemainingDomainForeignKeys1789750600000();
    await migration.up({ query } as unknown as QueryRunner);
    const sql = query.mock.calls.map(([statement]) => String(statement));
    expect(
      sql.filter((statement) => statement.includes('FOREIGN KEY')),
    ).toHaveLength(6);
    expect(
      sql.filter((statement) => statement.includes('CREATE INDEX')),
    ).toHaveLength(6);
    for (const statement of sql.filter((statement) =>
      statement.includes('FOREIGN KEY'),
    )) {
      expect(statement).toContain('ON DELETE RESTRICT NOT VALID');
    }
    expect(sql.join('\n')).not.toMatch(/DELETE FROM|TRUNCATE|UPDATE /);
    query.mockClear();
    await migration.down({ query } as unknown as QueryRunner);
    expect(query).toHaveBeenCalledTimes(13);
  });
});
