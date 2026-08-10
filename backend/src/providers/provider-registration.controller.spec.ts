import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AuthService } from '../auth/auth.service';
import { ProviderRegistrationController } from './provider-registration.controller';

describe('ProviderRegistrationController', () => {
  let app: INestApplication<App>;
  const response = {
    userId: 'provider-1',
    accessToken: 'access-token',
    tokenType: 'Bearer' as const,
    expiresIn: 900,
  };
  const registerProvider = jest.fn().mockResolvedValue(response);

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [ProviderRegistrationController],
      providers: [{ provide: AuthService, useValue: { registerProvider } }],
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

  afterAll(() => app.close());

  it('accepts validated provider registration without status or role input', async () => {
    await request(app.getHttpServer())
      .post('/auth/provider/register')
      .send({
        email: ' Provider@Example.COM ',
        password: 'Correct Horse Battery Staple!',
      })
      .expect(201)
      .expect(response);

    expect(registerProvider).toHaveBeenCalledWith({
      email: 'provider@example.com',
      password: 'Correct Horse Battery Staple!',
    });

    await request(app.getHttpServer())
      .post('/auth/provider/register')
      .send({
        email: 'provider@example.com',
        password: 'Correct Horse Battery Staple!',
        status: 'verified',
        role: 'verified_provider',
      })
      .expect(400);
  });
});
