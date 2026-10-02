import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger } from 'nestjs-pino';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import { SwaggerModule } from '@nestjs/swagger';
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
import { buildOpenApiDocument } from './openapi/openapi.document';
import { ObservabilityService } from './observability/observability.service';

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
  const observability = app.get(ObservabilityService);

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
  //
  // The `.use.bind(...)` is load-bearing, not stylistic. Express 5's
  // `app.use(fn)` inspects its first argument: anything that is not a *function*
  // is read as a mount path, and with a path and no handler left it throws
  // `app.use() requires a middleware function`. A `NestMiddleware` instance is
  // an object, so passing the instance straight through throws at boot — which
  // is what this did: the app never reached `listen`, the dev proxy answered
  // every request with 502, and the only visible symptom was a Flutter client
  // logging "Unable to connect". Binding `use` hands Express an actual function
  // and keeps the middleware in its intended order.
  const securityHeaders = new SecurityHeadersMiddleware(configService);
  app.use(securityHeaders.use.bind(securityHeaders));
  const requestCorrelation = new RequestCorrelationMiddleware();
  app.use(requestCorrelation.use.bind(requestCorrelation));
  // Registered after the correlation id so a metric and a log line for the same
  // request can be joined, and before anything that could fail, so a rejected
  // request is still counted.
  app.use(observability.instrumentHttp());

  const webOrigins = configService
    .get<string>('WEB_ALLOWED_ORIGINS')
    ?.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (webOrigins?.length) {
    app.enableCors({ origin: webOrigins, credentials: false });
  }
  // API-001. Mounted before `listen` so the document reflects every route the
  // instance actually registered, and served from the API's own origin rather
  // than the web origin, because it describes the API.
  //
  // `JSON` rather than the default `YAML`: the YAML output puts every path on the
  // same few enormous lines, which makes a diff of a changed route unreadable -
  // and the point of a committed document is that a reviewer can see what moved.
  const openApiDocument = buildOpenApiDocument(app);
  SwaggerModule.setup('api/docs', app, openApiDocument, {
    jsonDocumentUrl: 'api/docs/openapi.json',
    yamlDocumentUrl: 'api/docs/openapi.yaml',
    customSiteTitle: 'FixNow API',
  });

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
// Without this handler a boot failure is silent. `NestFactory.create` is called
// with `bufferLogs: true`, so Nest holds every log line until `useLogger` runs
// above; a throw before that point discards the whole buffer, and an unhandled
// rejection terminates the process with nothing on stdout. That is precisely how
// a middleware-registration bug presented as a Flutter client unable to connect,
// with no indication that the API had refused to start at all.
void bootstrap().catch((error: unknown) => {
  const message = error instanceof Error ? (error.stack ?? error.message) : String(error);
  // Deliberately not the app logger: it may be exactly what failed to attach.
  process.stderr.write(`FixNow API failed to start: ${message}\n`);
  process.exit(1);
});
