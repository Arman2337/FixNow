import { Test, TestingModule } from '@nestjs/testing';
import { DatabaseModule } from './database.module';
import { ConfigModule } from '@nestjs/config';

describe('DatabaseModule', () => {
  let module: TestingModule;

  beforeEach(async () => {
    // We mock the database module compilation without actual connection
    // to ensure our provider configuration and injection works.
    module = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          ignoreEnvVars: true,
          load: [
            () => ({
              DATABASE_URL: 'postgresql://fixnow:replace-me@localhost:5432/fixnow',
            }),
          ],
        }),
        DatabaseModule,
      ],
    }).compile();
  });

  it('should be defined', () => {
    expect(module).toBeDefined();
  });
});
