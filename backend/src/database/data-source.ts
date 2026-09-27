import 'dotenv/config';
import { DataSource, DataSourceOptions } from 'typeorm';

/**
 * A standalone TypeORM data source for schema migrations.
 *
 * Why this file exists: `database.module.ts` sets `migrationsRun: false` and
 * relies on `autoLoadEntities`, which only works inside a running Nest
 * application. The TypeORM CLI needs its own data source, and without one
 * `npm run typeorm` could not run at all - which is how the schema drift
 * described in reports/fixnow-critical-findings.md (BUG-001/BUG-002) reached
 * the database unnoticed.
 *
 * Keep this in sync with `createDatabaseOptions` in `database.module.ts`.
 */
export const migrationDataSourceOptions: DataSourceOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL,
  // Migrations are reviewed SQL, never generated from entity metadata.
  synchronize: false,
  migrationsRun: false,
  entities: [`${__dirname}/../**/*.entity.{ts,js}`],
  migrations: [`${__dirname}/../../migrations/*.{ts,js}`],
};

// Default export so `typeorm migration:run -d <this file>` works.
export default new DataSource(migrationDataSourceOptions);
