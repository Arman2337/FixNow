import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger } from 'nestjs-pino';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import type { Express } from 'express';
import { SecurityHeadersMiddleware } from './common/middleware/security-headers.middleware';
import { RequestCorrelationMiddleware } from './logging/request-correlation.middleware';

async function bootstrap() {
  // rawBody is required for HMAC webhook signature verification (FN-052).
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
    rawBody: true,
  });
  app.useLogger(app.get(Logger));
  app.useWebSocketAdapter(new WsAdapter(app));
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  const configService = app.get(ConfigService);

  // SEC-006. Express reads X-Forwarded-For for req.ip only when a proxy is
  // trusted. Left unset, the rate limiter buckets on the socket address - which
  // is correct, but means one shared NAT egress counts as one caller. Set the
  // real hop count in production; a permissive value would let a client forge
  // its own forwarded chain and escape the limit entirely.
  const trustProxyHops = configService.get<number>('TRUST_PROXY_HOPS');
  if (typeof trustProxyHops === 'number' && trustProxyHops > 0) {
    // getInstance() is typed `any`; the app is known to be Express here
    // because NestFactory.create picked the platform-express adapter.
    const express = app.getHttpAdapter().getInstance() as Express;
    express.set('trust proxy', trustProxyHops);
  }

  // OPS-003. Registered before CORS and the global prefix so no route can opt
  // out by being mounted earlier.
  app.use(new SecurityHeadersMiddleware(configService));
  app.use(new RequestCorrelationMiddleware());

  const webOrigins = configService
    .get<string>('WEB_ALLOWED_ORIGINS')
    ?.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (webOrigins?.length) {
    app.enableCors({ origin: webOrigins, credentials: false });
  }
  const port = configService.get<number>('PORT') ?? 3000;
  await app.listen(port);
}
void bootstrap();
