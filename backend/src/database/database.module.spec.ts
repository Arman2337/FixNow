import { ConfigService } from '@nestjs/config';
import { createDatabaseOptions } from './database.module';

describe('database configuration', () => {
  it('builds safe options without opening a database connection', () => {
    const get = jest.fn().mockReturnValue('postgresql://test-host/fixnow_test');
    const configService = { get } as unknown as ConfigService;

    expect(createDatabaseOptions(configService)).toEqual({
      type: 'postgres',
      url: 'postgresql://test-host/fixnow_test',
      autoLoadEntities: true,
      synchronize: false,
      migrationsRun: false,
    });
    expect(get).toHaveBeenCalledWith('DATABASE_URL');
  });
});
