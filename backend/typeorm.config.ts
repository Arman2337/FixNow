import { DataSource, DataSourceOptions } from 'typeorm';
import { config } from 'dotenv';
import { existsSync } from 'fs';
import { join } from 'path';

// Load environment variables from the closest .env when running from source or dist/
for (const candidate of [
  join(__dirname, '../.env'),
  join(__dirname, '../../.env'),
  join(__dirname, '../../../.env'),
]) {
  if (!process.env.DATABASE_URL && existsSync(candidate)) {
    config({ path: candidate });
  }
}

// Fallback to .env.example if DATABASE_URL is still missing
if (!process.env.DATABASE_URL) {
  for (const candidate of [
    join(__dirname, '../.env.example'),
    join(__dirname, '../../.env.example'),
    join(__dirname, '../../../.env.example'),
  ]) {
    if (existsSync(candidate)) {
      config({ path: candidate });
    }
  }
}

export const dataSourceOptions: DataSourceOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: [join(__dirname, 'src/**/*.entity{.ts,.js}')],
  migrations: [join(__dirname, 'migrations/*{.ts,.js}')],
  synchronize: false,
};

const dataSource = new DataSource(dataSourceOptions);
export default dataSource;
