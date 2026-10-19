import 'dotenv/config';
import { DataSource } from 'typeorm';
import { dataSourceOptions } from '../typeorm.config';

async function main(): Promise<void> {
  const adminUrl = process.env.DATABASE_URL!;
  const ds = new DataSource({
    ...(dataSourceOptions as unknown as Record<string, unknown>),
    url: adminUrl,
  } as never);
  await ds.initialize();
  await ds.query(`
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity
    WHERE datname = 'fixnow_integration_test' AND pid <> pg_backend_pid()
  `);
  await ds.query(`DROP DATABASE IF EXISTS "fixnow_integration_test"`);
  await ds.query(`CREATE DATABASE "fixnow_integration_test"`);
  await ds.destroy();
  console.log('Created database fixnow_integration_test');

  const testDbUrl = adminUrl.replace(/\/fixnow$/, '/fixnow_integration_test');
  const testDs = new DataSource({
    ...(dataSourceOptions as unknown as Record<string, unknown>),
    url: testDbUrl,
  } as never);
  await testDs.initialize();
  const runner = testDs.createQueryRunner();
  await runner.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
  await runner.query('CREATE EXTENSION IF NOT EXISTS pgcrypto');
  await runner.release();
  const applied = await testDs.runMigrations({ transaction: 'each' });
  console.log(`Applied ${applied.length} migrations to fixnow_integration_test`);
  await testDs.destroy();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
