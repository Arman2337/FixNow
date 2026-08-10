import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import { AuthService } from '../src/auth/auth.service';
import { CredentialEntity } from '../src/users/credential.entity';
import { IdentityEntity } from '../src/users/identity.entity';
import { RoleEntity } from '../src/users/role.entity';
import { UserRoleEntity } from '../src/users/user-role.entity';
import { UserEntity } from '../src/users/user.entity';

describe('customer authentication PostgreSQL boundaries', () => {
  const rawUrl = process.env.TEST_DATABASE_URL;
  if (!rawUrl)
    throw new Error('TEST_DATABASE_URL must target an isolated test database');
  const url = new URL(rawUrl);
  const isExpectedTestDatabase =
    url.protocol === 'postgresql:' &&
    ['127.0.0.1', 'localhost'].includes(url.hostname) &&
    url.port === '55432' &&
    url.username === 'fixnow_test' &&
    url.pathname === '/fixnow_test';
  if (!isExpectedTestDatabase) {
    throw new Error(
      'Refusing destructive integration tests: TEST_DATABASE_URL must be the documented loopback fixnow_test database on port 55432',
    );
  }

  const dataSource = new DataSource({
    type: 'postgres',
    url: rawUrl,
    entities: [
      UserEntity,
      IdentityEntity,
      CredentialEntity,
      RoleEntity,
      UserRoleEntity,
    ],
    synchronize: false,
  });
  const jwt = new JwtService({
    secret: 'test-only-jwt-secret-at-least-32-characters',
  });
  const service = new AuthService(dataSource, jwt);

  beforeAll(() => dataSource.initialize());
  beforeEach(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "auth_credentials", "user_roles", "user_identities", "users" CASCADE',
    );
    await dataSource.query(
      `INSERT INTO "roles" ("id", "code", "description") VALUES ('00000000-0000-4000-8000-000000000001', 'customer', 'Customer account') ON CONFLICT ("code") DO NOTHING`,
    );
  });
  afterAll(() => dataSource.destroy());

  it('registers, rejects duplicates, and logs in without storing plaintext credentials', async () => {
    const input = {
      email: 'customer@example.com',
      password: 'Correct Horse Battery Staple!',
    };
    const registration = await service.register(input);
    expect(registration.accessToken).toEqual(expect.any(String));

    const stored = await dataSource
      .getRepository(CredentialEntity)
      .findOneByOrFail({});
    expect(stored.passwordHash).not.toContain(input.password);

    await expect(service.register(input)).rejects.toMatchObject({
      status: 409,
    });
    await expect(service.login(input)).resolves.toMatchObject({
      userId: registration.userId,
      tokenType: 'Bearer',
    });
    await expect(
      service.login({ ...input, password: 'Wrong Password Value!' }),
    ).rejects.toMatchObject({ status: 401 });
  });
});
