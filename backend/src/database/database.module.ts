import { Module } from '@nestjs/common';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';

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
    // Point the application at the same migration history `typeorm.config.ts`
    // uses, so `migration:show` reflects reality instead of an empty list.
    // Kept as a glob rather than imported, because typeorm.config.ts calls
    // dotenv.config() as a side effect and the app is configured by Nest.
    migrations: [`${__dirname}/../../migrations/*{.ts,.js}`],
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
