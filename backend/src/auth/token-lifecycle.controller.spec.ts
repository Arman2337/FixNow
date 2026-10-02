import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import request from 'supertest';
import type { App } from 'supertest/types';
import { TokenLifecycleController } from './token-lifecycle.controller';
import { TokenLifecycleService } from './token-lifecycle.service';

/**
 * API-002. `POST /auth/token/refresh`, `/auth/logout` and `/auth/logout-all`
 * carried no `@Throttle`, so all three shared the global 60/min bucket.
 *
 * The refresh route is the one that matters: it is unauthenticated, it turns a
 * stolen refresh token into an access token, and each call runs a transaction
 * that takes a `FOR UPDATE` row lock on the session plus three or four writes.
 * These tests drive the real throttler through the real routes, because the
 * property being asserted is "this route has its own bucket", which a metadata
 * check alone would not prove — a `@Throttle` with a limit above the global one
 * would pass a metadata check and change nothing.
 */
describe('TokenLifecycleController rate limits (API-002)', () => {
  let app: INestApplication<App>;
  const lifecycle = {
    refresh: jest.fn().mockResolvedValue({
      userId: 'user-1',
      role: 'customer' as const,
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresInSeconds: 900,
    }),
    logout: jest.fn().mockResolvedValue(undefined),
  };
  const REFRESH = { refreshToken: 'a'.repeat(64) };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      imports: [ThrottlerModule.forRoot([{ ttl: 60_000, limit: 60 }])],
      controllers: [TokenLifecycleController],
      providers: [
        { provide: TokenLifecycleService, useValue: lifecycle },
        { provide: APP_GUARD, useClass: ThrottlerGuard },
      ],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });

  afterEach(async () => {
    await app?.close();
  });

  it('throttles token/refresh well below the global 60/min bucket', async () => {
    // 31 requests: one over the route's own 30/min limit. If the route were
    // still on the global bucket this would all succeed.
    const statuses: number[] = [];
    for (let i = 0; i < 31; i++) {
      const response = await request(app.getHttpServer())
        .post('/auth/token/refresh')
        .send(REFRESH);
      statuses.push(response.status);
    }

    expect(statuses.slice(0, 30).every((s) => s === 200)).toBe(true);
    expect(statuses[30]).toBe(429);
  });

  it('throttles logout-all more tightly than logout', async () => {
    const statuses: number[] = [];
    for (let i = 0; i < 11; i++) {
      const response = await request(app.getHttpServer())
        .post('/auth/logout-all')
        .send(REFRESH);
      statuses.push(response.status);
    }

    // 10/min, so the eleventh call is refused while logout's own 60/min is not
    // reached. `logout-all` revokes every session for the account, so one call
    // can invalidate a family that took many refreshes to build.
    expect(statuses.slice(0, 10).every((s) => s === 204)).toBe(true);
    expect(statuses[10]).toBe(429);
  });

  it('leaves logout within the global limit', async () => {
    const statuses: number[] = [];
    for (let i = 0; i < 20; i++) {
      const response = await request(app.getHttpServer())
        .post('/auth/logout')
        .send(REFRESH);
      statuses.push(response.status);
    }

    expect(statuses.every((s) => s === 204)).toBe(true);
  });

  it('gives each route its own bucket rather than a shared one', async () => {
    // Exhausting logout-all must not consume the refresh route's allowance:
    // they are separate operations with separate cost profiles, and sharing a
    // bucket means one abusive caller can lock a user out of both.
    for (let i = 0; i < 11; i++) {
      await request(app.getHttpServer()).post('/auth/logout-all').send(REFRESH);
    }

    const response = await request(app.getHttpServer())
      .post('/auth/token/refresh')
      .send(REFRESH);

    expect(response.status).toBe(200);
  });
});
