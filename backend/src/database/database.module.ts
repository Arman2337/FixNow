import { Module } from '@nestjs/common';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { migrationDataSourceOptions } from './data-source';

export function createDatabaseOptions(
  configService: ConfigService,
): TypeOrmModuleOptions {
  return {
    type: 'postgres',
    url: configService.get<string>('DATABASE_URL'),
    autoLoadEntities: true,
    // Schema changes are run through reviewed migrations. Never let a running
    // application mutate a database schema automatically.
    synchronize: false,
    migrationsRun: false,
    // Point the application at the same migration history the CLI uses, so
    // `typeorm migration:show` reflects reality instead of an empty list.
    migrations: migrationDataSourceOptions.migrations,
  };
}

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: createDatabaseOptions,
    }),
  ],
})
export class DatabaseModule {}
