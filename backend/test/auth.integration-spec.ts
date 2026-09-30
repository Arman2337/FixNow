import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
import { AuthService } from '../src/auth/auth.service';
import { TokenLifecycleService } from '../src/auth/token-lifecycle.service';
import { CredentialEntity } from '../src/users/credential.entity';
import { createTestDataSource } from './support/test-data-source';

describe('customer authentication PostgreSQL boundaries', () => {
  const dataSource: DataSource = createTestDataSource();
  const jwt = new JwtService({
    secret: 'test-only-jwt-secret-at-least-32-characters',
  });
  const lifecycle = new TokenLifecycleService(
    dataSource,
    jwt,
    new ConfigService({
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
    }),
    { sendVerificationCode: jest.fn() },
  );
  const service = new AuthService(dataSource, lifecycle);

  beforeAll(() => dataSource.initialize());
  beforeEach(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "auth_audit_events", "auth_sessions", "otp_challenges", "auth_credentials", "user_roles", "user_identities", "users" CASCADE',
    );
    await dataSource.query(
      `INSERT INTO "roles" ("id", "code", "description") VALUES ('00000000-0000-4000-8000-000000000001', 'customer', 'Customer account') ON CONFLICT ("code") DO NOTHING`,
    );
  });
  afterAll(() => dataSource.destroy());

  it('registers, rejects duplicates, and logs in without storing plaintext credentials', async () => {
    // `mobile` became mandatory for registration when OTP delivery moved onto
    // the account. The DTO still declares it optional; the service enforces it.
    // The suite had never run, so the old payload sat here failing.
    const input = {
      email: 'customer@example.com',
      password: 'Correct Horse Battery Staple!',
      mobile: '+919000000001',
    };
    const registration = await service.registerCustomer(input);
    expect(registration.accessToken).toEqual(expect.any(String));

    const stored = await dataSource
      .getRepository(CredentialEntity)
      .findOneByOrFail({});
    expect(stored.passwordHash).not.toContain(input.password);

    await expect(service.registerCustomer(input)).rejects.toMatchObject({
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

  it('refuses registration without a mobile number', async () => {
    await expect(
      service.registerCustomer({
        email: 'nomobile@example.com',
        password: 'Correct Horse Battery Staple!',
      }),
    ).rejects.toMatchObject({ status: 400 });
  });
});
