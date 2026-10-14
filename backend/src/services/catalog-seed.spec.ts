import {
  seedCatalog,
  getCatalogForSlug,
  CATALOG,
  getDatabaseUrl,
} from '../../seed';

describe('GAP-02 / FN-175: Catalog Seed Non-destructive & Idempotent Behaviour', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  describe('getDatabaseUrl', () => {
    it('throws when DATABASE_URL is missing or empty instead of silently using a fake connection string', () => {
      delete process.env.DATABASE_URL;
      expect(() => {
        getDatabaseUrl();
      }).toThrow(/DATABASE_URL environment variable is required/);

      process.env.DATABASE_URL = '   ';
      expect(() => {
        getDatabaseUrl();
      }).toThrow(/DATABASE_URL environment variable is required/);
    });

    it('returns trimmed DATABASE_URL when set', () => {
      process.env.DATABASE_URL = ' postgresql://app:sec@127.0.0.1:5432/fixnow ';
      expect(getDatabaseUrl()).toBe(
        'postgresql://app:sec@127.0.0.1:5432/fixnow',
      );
    });
  });

  describe('getCatalogForSlug', () => {
    it('resolves correct categories for standard slugs', () => {
      expect(getCatalogForSlug('plumbing')).toBe(CATALOG.plumbing);
      expect(getCatalogForSlug('electrical')).toBe(CATALOG.electrical);
      expect(getCatalogForSlug('hvac')).toBe(CATALOG.hvac);
      expect(getCatalogForSlug('ac-repair')).toBe(CATALOG.hvac);
      expect(getCatalogForSlug('home-cleaning')).toBe(CATALOG.cleaning);
    });

    it('returns null for unknown slugs to trigger standard fallback templates', () => {
      expect(getCatalogForSlug('unknown-niche-service')).toBeNull();
      expect(getCatalogForSlug('')).toBeNull();
    });
  });

  describe('seedCatalog idempotency and safety', () => {
    it('NEVER issues a DELETE FROM sub_services statement', async () => {
      const executedQueries: string[] = [];
      const mockClient = {
        query: jest
          .fn()
          .mockImplementation(async (sql: string, _params?: unknown[]) => {
            executedQueries.push(sql);
            if (sql === 'BEGIN' || sql === 'COMMIT' || sql === 'ROLLBACK') {
              return { rowCount: 0 };
            }
            if (sql.includes('SELECT id, slug, name FROM service_categories')) {
              return {
                rows: [
                  { id: 'cat-uuid-1', slug: 'plumbing', name: 'Plumbing' },
                  { id: 'cat-uuid-2', slug: 'electrical', name: 'Electrical' },
                ],
              };
            }
            // Conditional insert
            return { rowCount: 1 };
          }),
      };

      await seedCatalog(mockClient);

      // Verify that NO delete queries were issued across the whole run
      const hasDelete = executedQueries.some((q) => /\bDELETE\b/i.test(q));
      expect(hasDelete).toBe(false);
    });

    it('wraps execution in a transaction and commits on success', async () => {
      const callOrder: string[] = [];
      const mockClient = {
        query: jest.fn().mockImplementation(async (sql: string) => {
          if (sql === 'BEGIN') callOrder.push('BEGIN');
          if (sql === 'COMMIT') callOrder.push('COMMIT');
          if (sql === 'ROLLBACK') callOrder.push('ROLLBACK');
          if (sql.includes('SELECT id, slug, name FROM service_categories')) {
            return {
              rows: [{ id: 'cat-1', slug: 'emergency', name: 'Emergency' }],
            };
          }
          return { rowCount: 1 };
        }),
      };

      const result = await seedCatalog(mockClient);

      expect(callOrder[0]).toBe('BEGIN');
      expect(callOrder[callOrder.length - 1]).toBe('COMMIT');
      expect(result.insertedCount).toBe(CATALOG.emergency.length);
      expect(result.existingCount).toBe(0);
      expect(result.categoriesCount).toBe(1);
    });

    it('rolls back transaction and propagates error on failure', async () => {
      let rolledBack = false;
      const mockClient = {
        query: jest.fn().mockImplementation(async (sql: string) => {
          if (sql === 'BEGIN') return { rowCount: 0 };
          if (sql === 'ROLLBACK') {
            rolledBack = true;
            return { rowCount: 0 };
          }
          if (sql.includes('SELECT id, slug, name FROM service_categories')) {
            throw new Error('Connection terminated unexpectedly');
          }
          return { rowCount: 1 };
        }),
      };

      await expect(seedCatalog(mockClient)).rejects.toThrow(
        'Connection terminated unexpectedly',
      );
      expect(rolledBack).toBe(true);
    });

    it('is strictly idempotent and preserves existing / admin-curated sub-services', async () => {
      // Simulating when sub-services already exist (e.g. on second deploy boot):
      // WHERE NOT EXISTS causes PostgreSQL to insert 0 rows
      const insertCalls: { sql: string; params?: unknown[] }[] = [];
      const mockClient = {
        query: jest
          .fn()
          .mockImplementation(async (sql: string, params?: unknown[]) => {
            if (sql === 'BEGIN' || sql === 'COMMIT') return { rowCount: 0 };
            if (sql.includes('SELECT id, slug, name FROM service_categories')) {
              return {
                rows: [
                  { id: 'cat-plumbing', slug: 'plumbing', name: 'Plumbing' },
                ],
              };
            }
            if (sql.includes('INSERT INTO sub_services')) {
              insertCalls.push({ sql, params });
              // 0 rows inserted because rows already exist
              return { rowCount: 0 };
            }
            return { rowCount: 0 };
          }),
      };

      const result = await seedCatalog(mockClient);

      // Asserts conditional insert WHERE NOT EXISTS was utilized
      expect(insertCalls.length).toBe(CATALOG.plumbing.length);
      for (const call of insertCalls) {
        expect(call.sql).toContain('WHERE NOT EXISTS');
        expect(call.sql).toContain(
          'SELECT 1 FROM sub_services WHERE category_id = $1::uuid AND name = $2::varchar',
        );
      }

      // 0 new inserts, all existing preserved
      expect(result.insertedCount).toBe(0);
      expect(result.existingCount).toBe(CATALOG.plumbing.length);
    });

    it('uses fallback catalog for custom categories created by admin', async () => {
      const mockClient = {
        query: jest
          .fn()
          .mockImplementation(async (sql: string, _params?: unknown[]) => {
            if (sql === 'BEGIN' || sql === 'COMMIT') return { rowCount: 0 };
            if (sql.includes('SELECT id, slug, name FROM service_categories')) {
              return {
                rows: [
                  {
                    id: 'cat-custom',
                    slug: 'solar-energy-audit',
                    name: 'Solar Panels',
                  },
                ],
              };
            }
            return { rowCount: 1 };
          }),
      };

      const result = await seedCatalog(mockClient);
      expect(result.insertedCount).toBe(2); // Standard inspection + overhaul fallback templates
      expect(result.categoriesCount).toBe(1);
    });
  });
});
