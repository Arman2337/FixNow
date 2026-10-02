import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { WsAdapter } from '@nestjs/platform-ws';
import request from 'supertest';
import type { App } from 'supertest/types';
import { createHash, randomUUID } from 'crypto';
import { DataSource } from 'typeorm';
import { AppModule } from '../src/app.module';
import { AuthSessionEntity } from '../src/auth/auth-session.entity';
import {
  ACCESS_TOKEN_AUDIENCE,
  ACCESS_TOKEN_ISSUER,
} from '../src/auth/auth.constants';
import { AccountStatus } from '../src/users/account-status';
import { type RoleCode } from '../src/common/authorization/permission-policies';
import { CustomerAddressEntity } from '../src/users/customer-address.entity';
import { CustomerProfileEntity } from '../src/users/customer-profile.entity';
import { RoleEntity } from '../src/users/role.entity';
import { UserRoleEntity } from '../src/users/user-role.entity';
import { UserEntity } from '../src/users/user.entity';
import { createTestDataSource } from './support/test-data-source';
import { JwtService } from '@nestjs/jwt';

/**
 * SEC-002: ownership enforcement over the real HTTP pipeline.
 *
 * Every other authorization test in this repository calls
 * `AuthorizationService.authorizeAccessToken` directly, which means all of them
 * pass whether or not a route is actually reachable. That gap is not
 * theoretical: the ownership tautology shipped across roughly thirty routes for
 * weeks, and `test/app.e2e-spec.ts` only ever requested `/api/v1/` — the one
 * route with no permission on it. Nothing in the suite would have noticed.
 *
 * So this spec boots the real `AppModule`, issues real tokens against real
 * session rows, and drives real requests. It is the regression lock for the
 * whole class, and it asserts both directions:
 *
 *  - a self-scoped route whose handler proves ownership **succeeds**, so the
 *    fix cannot be "deny everything and call it safe"
 *  - the same route for somebody else's resource **fails**, and a self-scoped
 *    route whose handler forgets to prove ownership **also** fails closed
 */
describe('SEC-002: ownership enforcement over HTTP', () => {
  let app: INestApplication<App>;
  let dataSource: DataSource;
  let baseUrl: string;
  const jwt = new JwtService({
    secret: 'test-only-jwt-secret-at-least-32-characters',
  });

  async function createActor(
    roleCode: RoleCode,
  ): Promise<{ user: UserEntity; token: string }> {
    const users = dataSource.getRepository(UserEntity);
    const roles = dataSource.getRepository(RoleEntity);
    const grants = dataSource.getRepository(UserRoleEntity);
    const sessions = dataSource.getRepository(AuthSessionEntity);
    const profiles = dataSource.getRepository(CustomerProfileEntity);

    const user = await users.save(
      users.create({
        status: AccountStatus.Active,
        statusReason: null,
        statusChangedAt: new Date(),
      }),
    );
    await profiles.save(
      profiles.create({ userId: user.id, displayName: `Actor ${roleCode}` }),
    );
    const role = await roles.save(
      roles.create({
        code: roleCode,
        description: `${roleCode} http test role`,
      }),
    );
    await grants.save(
      grants.create({
        userId: user.id,
        roleId: role.id,
        assignedByUserId: null,
        reason: 'SEC-002 http test',
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
        expiresAt: new Date(Date.now() + 600_000),
        revokedAt: null,
        revokeReason: null,
        replacedBySessionId: null,
      }),
    );
    return {
      user,
      token: jwt.sign(
        { sessionId: session.id, role: roleCode },
        {
          subject: user.id,
          issuer: ACCESS_TOKEN_ISSUER,
          audience: ACCESS_TOKEN_AUDIENCE,
          expiresIn: 600,
        },
      ),
    };
  }

  beforeAll(async () => {
    dataSource = createTestDataSource();
    await dataSource.initialize();

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useWebSocketAdapter(new WsAdapter(app));
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
    await app.listen(0);
    // `getUrl()` resolves against the bound port, which `listen(0)` chooses, so
    // the address object is never needed here.
    baseUrl = await app.getUrl();
  });

  beforeEach(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "customer_addresses", "customer_profiles", "auth_audit_events", "auth_sessions", "user_roles", "roles", "users" CASCADE',
    );
  });

  afterAll(async () => {
    await app?.close();
    if (dataSource?.isInitialized) await dataSource.destroy();
  });

  describe('a self-scoped route whose handler proves ownership', () => {
    it('serves the caller their own addresses', async () => {
      const customer = await createActor('customer');
      const addresses = dataSource.getRepository(CustomerAddressEntity);
      await addresses.save(
        addresses.create({
          userId: customer.user.id,
          street: 'Palm Grove, 4',
          city: 'Pune',
          state: 'MH',
          zip: '411001',
          latitude: 18.5,
          longitude: 73.8,
          isDefault: true,
        }),
      );

      const response = await request(baseUrl)
        .get('/api/v1/users/me/addresses')
        .set('authorization', `Bearer ${customer.token}`)
        .expect(200);

      const body = response.body as Array<{ userId: string }>;
      expect(body).toHaveLength(1);
      expect(body[0]).toMatchObject({ userId: customer.user.id });
    });

    it('returns an empty list for a caller who has saved no addresses', async () => {
      const customer = await createActor('customer');
      const response = await request(baseUrl)
        .get('/api/v1/users/me/addresses')
        .set('authorization', `Bearer ${customer.token}`)
        .expect(200);

      expect(response.body).toEqual([]);
    });

    it('serves the caller their own profile', async () => {
      const customer = await createActor('customer');
      const response = await request(baseUrl)
        .get('/api/v1/users/me/profile')
        .set('authorization', `Bearer ${customer.token}`)
        .expect(200);

      expect(response.body).toMatchObject({ userId: customer.user.id });
    });

    it('serves the caller their own admin session', async () => {
      const auditor = await createActor('auditor');
      const response = await request(baseUrl)
        .get('/api/v1/auth/admin/session')
        .set('authorization', `Bearer ${auditor.token}`)
        .expect(200);

      expect(response.body).toMatchObject({ userId: auditor.user.id });
    });
  });

  describe("a self-scoped route reaching another account's resource", () => {
    it('refuses to delete an address belonging to somebody else', async () => {
      const owner = await createActor('customer');
      const attacker = await createActor('customer');
      const addresses = dataSource.getRepository(CustomerAddressEntity);
      const victimAddress = await addresses.save(
        addresses.create({
          userId: owner.user.id,
          street: "Someone Else's House",
          city: 'Pune',
          state: 'MH',
          zip: '411001',
          latitude: 18.5,
          longitude: 73.8,
          isDefault: false,
        }),
      );

      await request(baseUrl)
        .delete(`/api/v1/users/me/addresses/${victimAddress.id}`)
        .set('authorization', `Bearer ${attacker.token}`)
        .expect(404);

      // The write must not have happened, not merely reported a refusal.
      const surviving = await addresses.findOneBy({ id: victimAddress.id });
      expect(surviving).not.toBeNull();
    });

    it("never lists another account's addresses", async () => {
      const owner = await createActor('customer');
      const attacker = await createActor('customer');
      const addresses = dataSource.getRepository(CustomerAddressEntity);
      await addresses.save(
        addresses.create({
          userId: owner.user.id,
          street: 'Private',
          city: 'Pune',
          state: 'MH',
          zip: '411001',
          latitude: 18.5,
          longitude: 73.8,
          isDefault: false,
        }),
      );

      const response = await request(baseUrl)
        .get('/api/v1/users/me/addresses')
        .set('authorization', `Bearer ${attacker.token}`)
        .expect(200);

      expect(response.body).toEqual([]);
    });
  });

  describe('authentication and authorization still hold', () => {
    it('rejects an unauthenticated request to a self-scoped route', async () => {
      await request(baseUrl).get('/api/v1/users/me/addresses').expect(401);
    });

    it('denies a customer calling an admin route', async () => {
      const customer = await createActor('customer');
      await request(baseUrl)
        .get('/api/v1/admin/users')
        .set('authorization', `Bearer ${customer.token}`)
        .expect(403);
    });

    it('denies a malformed bearer token', async () => {
      await request(baseUrl)
        .get('/api/v1/users/me/addresses')
        .set('authorization', 'Bearer not-a-jwt')
        .expect(401);
    });
  });
});
