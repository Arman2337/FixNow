import { DataSource } from 'typeorm';
import { GroupServicesService } from './group-services.service';

describe('GroupServicesService schema compatibility', () => {
  function makeDataSource(schemaColumnCount: number) {
    const txQuery = jest.fn();
    const dataQuery = jest.fn(async (sql: string) => {
      if (sql.includes('information_schema.columns')) {
        return [{ count: schemaColumnCount }];
      }
      return [];
    });
    const tx = { query: txQuery };
    const ds = {
      query: dataQuery,
      transaction: jest.fn(
        (
          isolationOrCb: unknown,
          maybeCb?: (manager: { query: jest.Mock }) => unknown,
        ) => {
          const cb =
            typeof isolationOrCb === 'function'
              ? (isolationOrCb as (manager: { query: jest.Mock }) => unknown)
              : maybeCb!;
          return cb(tx);
        },
      ),
    } as unknown as DataSource;
    return { ds, dataQuery, txQuery };
  }

  it('uses legacy queries without enhancement columns when DB migration 1789750900000 is absent', async () => {
    const { ds, dataQuery } = makeDataSource(0);
    const service = new GroupServicesService(ds);

    await service.listCustomer('user-1');
    await service.listProvider('prov-1');

    const executedSql = dataQuery.mock.calls.map((c) => String(c[0]));
    const customerSql = executedSql.find((s) =>
      s.includes('AS "membershipStatus"'),
    );
    const providerSql = executedSql.find((s) => s.includes('AS "ownQuoteId"'));
    expect(customerSql).toBeDefined();
    expect(customerSql).not.toContain('g.service_address');
    expect(customerSql).not.toContain('m.status');
    expect(providerSql).toBeDefined();
    expect(providerSql).not.toContain('g.service_address');
  });

  it('uses full enhancement columns once all 6 migration columns exist', async () => {
    const { ds, dataQuery } = makeDataSource(6);
    const service = new GroupServicesService(ds);

    await service.listCustomer('user-1');
    await service.listProvider('prov-1');

    const executedSql = dataQuery.mock.calls.map((c) => String(c[0]));
    const customerSql = executedSql.find((s) =>
      s.includes('m.service_address AS "myServiceAddress"'),
    );
    const providerSql = executedSql.find((s) =>
      s.includes('g.service_address END AS "selectedServiceAddress"'),
    );
    expect(customerSql).toContain('g.service_address AS "serviceAddress"');
    expect(customerSql).toContain('m.status AS "membershipStatus"');
    expect(providerSql).toContain('g.service_status AS "serviceStatus"');
  });
});
