import { ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomUUID } from 'crypto';
import { DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../src/auth/auth-audit-event.entity';
import { AuthSessionEntity } from '../src/auth/auth-session.entity';
import {
  ACCESS_TOKEN_AUDIENCE,
  ACCESS_TOKEN_ISSUER,
} from '../src/auth/auth.constants';
import { AuthorizationPolicyService } from '../src/common/authorization/authorization-policy.service';
import { AuthorizationService } from '../src/common/authorization/authorization.service';
import {
  PERMISSIONS,
  RoleCode,
} from '../src/common/authorization/permission-policies';
import { AccountStatus } from '../src/users/account-status';
import { RoleEntity } from '../src/users/role.entity';
import { UserRoleEntity } from '../src/users/user-role.entity';
import { UserEntity } from '../src/users/user.entity';

describe('authorization PostgreSQL boundaries', () => {
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
      RoleEntity,
      UserRoleEntity,
      AuthSessionEntity,
      AuthAuditEventEntity,
    ],
    synchronize: false,
  });
  const jwt = new JwtService({
    secret: 'test-only-jwt-secret-at-least-32-characters',
  });
  const authorization = new AuthorizationService(
    dataSource,
    jwt,
    new AuthorizationPolicyService(),
  );

  beforeAll(() => dataSource.initialize());
  beforeEach(() =>
    dataSource.query(
      'TRUNCATE TABLE "auth_audit_events", "auth_sessions", "user_roles", "roles", "users" CASCADE',
    ),
  );
  afterAll(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "auth_audit_events", "auth_sessions", "user_roles", "roles", "users" CASCADE',
    );
    await dataSource.destroy();
  });

  async function createActor(
    roleCode: RoleCode,
    status = AccountStatus.Active,
  ): Promise<{ user: UserEntity; token: string }> {
    const users = dataSource.getRepository(UserEntity);
    const roles = dataSource.getRepository(RoleEntity);
    const grants = dataSource.getRepository(UserRoleEntity);
    const sessions = dataSource.getRepository(AuthSessionEntity);
    const user = await users.save(
      users.create({ status, statusReason: null, statusChangedAt: new Date() }),
    );
    const role = await roles.save(
      roles.create({ code: roleCode, description: `${roleCode} test role` }),
    );
    await grants.save(
      grants.create({
        userId: user.id,
        roleId: role.id,
        assignedByUserId: null,
        reason: 'authorization test',
        expiresAt: null,
      }),
    );
    const session = await sessions.save(
      sessions.create({
        userId: user.id,
        tokenFamilyId: randomUUID(),
        refreshTokenHash: createHash('sha256')
          .update(randomUUID())
          .digest('hex'),
        role: roleCode,
        expiresAt: new Date(Date.now() + 60_000),
        revokedAt: null,
        revokeReason: null,
        replacedBySessionId: null,
      }),
    );
    return {
      user,
      token: jwt.sign(
        { sessionId: session.id, role: 'security_administrator' },
        {
          subject: user.id,
          issuer: ACCESS_TOKEN_ISSUER,
          audience: ACCESS_TOKEN_AUDIENCE,
          expiresIn: 60,
        },
      ),
    };
  }

  it('allows own customer access and denies cross-role access', async () => {
    const customer = await createActor('customer');
    const applicant = await createActor('provider_applicant');
    await expect(
      authorization.authorizeAccessToken(
        customer.token,
        PERMISSIONS.bookingCreateSelf,
        { ownerId: customer.user.id },
      ),
    ).resolves.toMatchObject({ userId: customer.user.id, roles: ['customer'] });
    await expect(
      authorization.authorizeAccessToken(
        applicant.token,
        PERMISSIONS.bookingCreateSelf,
        { ownerId: applicant.user.id },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('denies an inactive account even with an otherwise valid grant', async () => {
    const customer = await createActor('customer', AccountStatus.Suspended);
    await expect(
      authorization.authorizeAccessToken(
        customer.token,
        PERMISSIONS.profileReadSelf,
        { ownerId: customer.user.id },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('denies ownership tampering', async () => {
    const customer = await createActor('customer');
    await expect(
      authorization.authorizeAccessToken(
        customer.token,
        PERMISSIONS.profileReadSelf,
        { ownerId: randomUUID() },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('ignores token role escalation and enforces independent non-self grants', async () => {
    const customer = await createActor('customer');
    await expect(
      authorization.authorizeAccessToken(
        customer.token,
        PERMISSIONS.roleGrantAuthorized,
        { targetPrincipalId: randomUUID(), independentApproval: true },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);

    const security = await createActor('security_administrator');
    await expect(
      authorization.authorizeAccessToken(
        security.token,
        PERMISSIONS.roleGrantAuthorized,
        {
          targetPrincipalId: security.user.id,
          independentApproval: true,
        },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      authorization.authorizeAccessToken(
        security.token,
        PERMISSIONS.roleGrantAuthorized,
        { targetPrincipalId: randomUUID(), independentApproval: true },
      ),
    ).resolves.toMatchObject({ userId: security.user.id });

    const audit = await dataSource.getRepository(AuthAuditEventEntity).find();
    expect(audit.map((event) => event.eventType)).toEqual(
      expect.arrayContaining(['authorization.allowed', 'authorization.denied']),
    );
  });
});
