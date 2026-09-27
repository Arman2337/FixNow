import { ConfigService } from '@nestjs/config';
import { createDatabaseOptions } from './database.module';

describe('database configuration', () => {
  it('builds safe options without opening a database connection', () => {
    const get = jest.fn().mockReturnValue('postgresql://test-host/fixnow_test');
    const configService = { get } as unknown as ConfigService;

    const options = createDatabaseOptions(configService);

    expect(options).toEqual({
      type: 'postgres',
      url: 'postgresql://test-host/fixnow_test',
      autoLoadEntities: true,
      synchronize: false,
      migrationsRun: false,
      // The app must see the same migration history the CLI uses.
      migrations: [`${__dirname}/../../migrations/*{.ts,.js}`],
    });
    expect(get).toHaveBeenCalledWith('DATABASE_URL');
  });

  it('never lets the application mutate the schema on its own', () => {
    const get = jest.fn().mockReturnValue('postgresql://test-host/fixnow_test');
    const configService = { get } as unknown as ConfigService;

    const options = createDatabaseOptions(configService);
    // synchronize would rewrite tables from entity metadata; migrationsRun
    // would apply migrations as a side effect of booting.
    expect(options.synchronize).toBe(false);
    expect(options.migrationsRun).toBe(false);
  });

  it('points at the migrations directory the CLI reads', () => {
    const get = jest.fn().mockReturnValue('postgresql://test-host/fixnow_test');
    const configService = { get } as unknown as ConfigService;

    const globs = createDatabaseOptions(configService).migrations as string[];
    expect(globs).toHaveLength(1);
    expect(globs[0]).toContain('migrations');
  });
});
