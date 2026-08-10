import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../src/auth/auth-audit-event.entity';
import { AuthSessionEntity } from '../src/auth/auth-session.entity';
import { AuthService } from '../src/auth/auth.service';
import { OtpChallengeEntity } from '../src/auth/otp-challenge.entity';
import { TokenLifecycleService } from '../src/auth/token-lifecycle.service';
import { ProviderApplicationEntity } from '../src/providers/provider-application.entity';
import { AccountStatus } from '../src/users/account-status';
import { CredentialEntity } from '../src/users/credential.entity';
import { IdentityEntity } from '../src/users/identity.entity';
import { RoleEntity } from '../src/users/role.entity';
import { UserRoleEntity } from '../src/users/user-role.entity';
import { UserEntity } from '../src/users/user.entity';

describe('OTP and refresh-token PostgreSQL boundaries', () => {
  const rawUrl = process.env.TEST_DATABASE_URL;
  if (!rawUrl)
    throw new Error('TEST_DATABASE_URL must target an isolated test database');
  const url = new URL(rawUrl);
  if (
    url.protocol !== 'postgresql:' ||
    !['127.0.0.1', 'localhost'].includes(url.hostname) ||
    url.port !== '55432' ||
    url.username !== 'fixnow_test' ||
    url.pathname !== '/fixnow_test'
  ) {
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
      OtpChallengeEntity,
      AuthAuditEventEntity,
    ],
    synchronize: false,
  });
  const sendVerificationCode = jest.fn<Promise<void>, [string, string]>(() =>
    Promise.resolve(),
  );
  const lifecycle = new TokenLifecycleService(
    dataSource,
    new JwtService({
      secret: 'test-only-jwt-secret-at-least-32-characters',
    }),
    new ConfigService({
      OTP_SECRET: 'test-only-otp-secret-at-least-32-characters',
    }),
    { sendVerificationCode },
  );
  const auth = new AuthService(dataSource, lifecycle);
  const input = {
    email: 'customer@example.com',
    password: 'Correct Horse Battery Staple!',
  };

  beforeAll(() => dataSource.initialize());
  beforeEach(async () => {
    jest.clearAllMocks();
    await dataSource.query(
      'TRUNCATE TABLE "auth_audit_events", "auth_sessions", "otp_challenges", "provider_applications", "auth_credentials", "user_roles", "user_identities", "users" CASCADE',
    );
    await dataSource.query(
      `INSERT INTO "roles" ("id", "code", "description") VALUES ('00000000-0000-4000-8000-000000000001', 'customer', 'Customer account') ON CONFLICT ("code") DO NOTHING`,
    );
  });
  afterAll(() => dataSource.destroy());

  it('enforces OTP resend, expiry, five attempts, and one-time verification', async () => {
    const registration = await auth.registerCustomer(input);
    await lifecycle.requestOtp(input.email);
    const firstCode = sendVerificationCode.mock.calls[0][1];
    await expect(lifecycle.requestOtp(input.email)).rejects.toMatchObject({
      status: 429,
    });
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await expect(
        lifecycle.verifyOtp(input.email, '000000'),
      ).rejects.toMatchObject({ status: 401 });
    }
    await expect(
      lifecycle.verifyOtp(input.email, firstCode),
    ).rejects.toMatchObject({ status: 401 });

    await dataSource.query(
      `UPDATE "otp_challenges" SET "resend_after" = NOW() - INTERVAL '1 second'`,
    );
    await lifecycle.requestOtp(input.email);
    const expiredCode = sendVerificationCode.mock.calls[1][1];
    await dataSource.query(
      `UPDATE "otp_challenges" SET "expires_at" = NOW() - INTERVAL '1 second' WHERE "code_hash" = (SELECT "code_hash" FROM "otp_challenges" ORDER BY "created_at" DESC LIMIT 1)`,
    );
    await expect(
      lifecycle.verifyOtp(input.email, expiredCode),
    ).rejects.toMatchObject({ status: 401 });

    await dataSource.query(
      `UPDATE "otp_challenges" SET "resend_after" = NOW() - INTERVAL '1 second'`,
    );
    await lifecycle.requestOtp(input.email);
    const validCode = sendVerificationCode.mock.calls[2][1];
    await lifecycle.verifyOtp(input.email, validCode);
    const user = await dataSource
      .getRepository(UserEntity)
      .findOneByOrFail({ id: registration.userId });
    expect(user.status).toBe(AccountStatus.Active);
    await expect(
      lifecycle.verifyOtp(input.email, validCode),
    ).rejects.toMatchObject({ status: 401 });
  });

  it('rotates once and revokes the token family when a rotated token is replayed', async () => {
    const registration = await auth.registerCustomer(input);
    const rotated = await lifecycle.refresh(registration.refreshToken);
    expect(rotated.refreshToken).not.toBe(registration.refreshToken);
    await expect(
      lifecycle.refresh(registration.refreshToken),
    ).rejects.toMatchObject({ status: 401 });
    await expect(lifecycle.refresh(rotated.refreshToken)).rejects.toMatchObject(
      {
        status: 401,
      },
    );
    const replayAudit = await dataSource
      .getRepository(AuthAuditEventEntity)
      .findOneBy({ eventType: 'session.replay_detected' });
    expect(replayAudit?.outcome).toBe('denied');
  });

  it('rejects and records an expired refresh token', async () => {
    const registration = await auth.registerCustomer(input);
    await dataSource.query(
      `UPDATE "auth_sessions" SET "expires_at" = NOW() - INTERVAL '1 second'`,
    );
    await expect(
      lifecycle.refresh(registration.refreshToken),
    ).rejects.toMatchObject({ status: 401 });
    const session = await dataSource
      .getRepository(AuthSessionEntity)
      .findOneByOrFail({ userId: registration.userId });
    expect(session.revokeReason).toBe('expired');
  });

  it('revokes the current session and all sessions explicitly', async () => {
    const first = await auth.registerCustomer(input);
    const second = await auth.login(input);
    await lifecycle.logout(first.refreshToken, false);
    await expect(lifecycle.refresh(first.refreshToken)).rejects.toMatchObject({
      status: 401,
    });
    const rotatedSecond = await lifecycle.refresh(second.refreshToken);
    await lifecycle.logout(rotatedSecond.refreshToken, true);
    await expect(
      lifecycle.refresh(rotatedSecond.refreshToken),
    ).rejects.toMatchObject({ status: 401 });
  });
});
