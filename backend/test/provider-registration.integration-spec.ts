import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { DataSource, QueryFailedError } from 'typeorm';
import { AuthService } from '../src/auth/auth.service';
import { TokenLifecycleService } from '../src/auth/token-lifecycle.service';
import { ProviderApplicationEntity } from '../src/providers/provider-application.entity';
import { ProviderOnboardingStatus } from '../src/providers/provider-onboarding-status';
import { UserRoleEntity } from '../src/users/user-role.entity';
import { createTestDataSource } from './support/test-data-source';

describe('provider registration PostgreSQL boundaries', () => {
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
      'TRUNCATE TABLE "auth_audit_events", "auth_sessions", "otp_challenges", "provider_applications", "auth_credentials", "user_roles", "user_identities", "users" CASCADE',
    );
    await dataSource.query(
      `INSERT INTO "roles" ("id", "code", "description") VALUES ('00000000-0000-4000-8000-000000000002', 'provider_applicant', 'Unverified provider applicant') ON CONFLICT ("code") DO NOTHING`,
    );
  });
  afterAll(() => dataSource.destroy());

  it('creates one unverified provider applicant and rejects duplicate or invalid state', async () => {
    const input = {
      email: 'provider@example.com',
      password: 'Correct Horse Battery Staple!',
      mobile: '+919000000002',
    };
    const registration = await service.registerProvider(input);
    const application = await dataSource
      .getRepository(ProviderApplicationEntity)
      .findOneByOrFail({ userId: registration.userId });
    expect(application.status).toBe(ProviderOnboardingStatus.Unverified);

    const assignment = await dataSource.getRepository(UserRoleEntity).findOne({
      where: { userId: registration.userId },
      relations: { role: true },
    });
    expect(assignment?.role.code).toBe('provider_applicant');
    await expect(service.registerProvider(input)).rejects.toMatchObject({
      status: 409,
    });
    await expect(
      dataSource.query(
        `UPDATE "provider_applications" SET "status" = 'verified' WHERE "user_id" = $1`,
        [registration.userId],
      ),
    ).rejects.toBeInstanceOf(QueryFailedError);
  });
});
