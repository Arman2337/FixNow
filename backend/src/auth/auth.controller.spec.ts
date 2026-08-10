import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import request from 'supertest';
import { App } from 'supertest/types';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let app: INestApplication<App>;
  const response = {
    userId: 'user-1',
    accessToken: 'access-token',
    tokenType: 'Bearer' as const,
    expiresIn: 900,
  };
  const authService = {
    register: jest.fn().mockResolvedValue(response),
    login: jest.fn().mockResolvedValue(response),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      imports: [ThrottlerModule.forRoot([{ ttl: 60_000, limit: 60 }])],
      controllers: [AuthController],
      providers: [
        { provide: AuthService, useValue: authService },
        { provide: APP_GUARD, useClass: ThrottlerGuard },
      ],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
  });

  afterEach(() => app.close());

  it('normalizes registration email and rejects invalid input', async () => {
    await request(app.getHttpServer())
      .post('/auth/customer/register')
      .send({
        email: '  Customer@Example.COM ',
        password: 'Correct Horse Battery Staple!',
      })
      .expect(201)
      .expect(response);

    expect(authService.register).toHaveBeenCalledWith({
      email: 'customer@example.com',
      password: 'Correct Horse Battery Staple!',
    });

    await request(app.getHttpServer())
      .post('/auth/customer/register')
      .send({ email: 'not-an-email', password: 'short' })
      .expect(400);
  });

  it('throttles login after five attempts per minute', async () => {
    const payload = {
      email: 'customer@example.com',
      password: 'Wrong Password Value!',
    };
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await request(app.getHttpServer())
        .post('/auth/customer/login')
        .send(payload)
        .expect(200);
    }
    await request(app.getHttpServer())
      .post('/auth/customer/login')
      .send(payload)
      .expect(429)
      .expect('Retry-After', /\d+/);
  });
});
