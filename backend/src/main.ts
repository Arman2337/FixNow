import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger } from 'nestjs-pino';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import type { Server } from 'node:http';
import type { Express } from 'express';
import { SecurityHeadersMiddleware } from './common/middleware/security-headers.middleware';
import { RequestCorrelationMiddleware } from './logging/request-correlation.middleware';
import {
  ReadinessState,
  SHUTDOWN_TIMEOUT_MS,
} from './health/readiness-state.service';
import {
  runGracefulShutdown,
  type ShutdownLogger,
} from './common/graceful-shutdown';

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
  // `app.get` is typed `any` on the base interface, so the logger is bound to
  // the pino shape the rest of the code actually uses. Without the annotation
  // every `appLogger.warn` below is an unchecked call on `any`, which is exactly
  // the class of mistake the shutdown path cannot afford.
  const appLogger = app.get<ShutdownLogger>(Logger);
  const readiness = app.get(ReadinessState);

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
  // Typed as the Node server because the boot-failure handler below needs its
  // `error` event; `INestApplication.listen` returns `any`.
  const server = (await app.listen(port)) as Server;

  // OPS-002. Three `onModuleDestroy` handlers existed and were never called: the
  // emergency scanner's interval, the reminder scanner's, and the realtime
  // gateway's heartbeat plus every open socket. Nest only invokes them in
  // response to its own shutdown signals, which are off unless
  // `enableShutdownHooks` is called - so a deploy SIGTERM'd the process, Node
  // killed it mid-tick, and a push fan-out or a heartbeat pass was abandoned
  // wherever it happened to be.
  app.enableShutdownHooks(['SIGTERM', 'SIGINT']);
  runGracefulShutdown({
    app,
    readiness,
    logger: appLogger,
    timeoutMs: SHUTDOWN_TIMEOUT_MS,
  });

  // Fail the boot loudly rather than leaving a process that answers requests it
  // cannot serve. `listen` resolves before the socket is actually accepting in
  // some failure modes, so this is the difference between a crash loop that
  // restarts and a pod that looks healthy while dropping every request.
  server.on('error', (error: Error) => {
    appLogger.error(
      `HTTP server error: ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
    process.exit(1);
  });

  appLogger.log(`FixNow API listening on port ${port}.`);
}
void bootstrap();
