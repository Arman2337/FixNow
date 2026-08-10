import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { DataSource, QueryFailedError } from 'typeorm';
import { AuthService } from '../src/auth/auth.service';
import { AuthSessionEntity } from '../src/auth/auth-session.entity';
import { AuthAuditEventEntity } from '../src/auth/auth-audit-event.entity';
import { OtpChallengeEntity } from '../src/auth/otp-challenge.entity';
import { TokenLifecycleService } from '../src/auth/token-lifecycle.service';
import { ProviderApplicationEntity } from '../src/providers/provider-application.entity';
import { ProviderOnboardingStatus } from '../src/providers/provider-onboarding-status';
import { CredentialEntity } from '../src/users/credential.entity';
import { IdentityEntity } from '../src/users/identity.entity';
import { RoleEntity } from '../src/users/role.entity';
import { UserRoleEntity } from '../src/users/user-role.entity';
import { UserEntity } from '../src/users/user.entity';

describe('provider registration PostgreSQL boundaries', () => {
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
      ProviderApplicationEntity,
      AuthSessionEntity,
      AuthAuditEventEntity,
      OtpChallengeEntity,
    ],
    synchronize: false,
  });
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
