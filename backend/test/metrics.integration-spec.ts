import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { WsAdapter } from '@nestjs/platform-ws';
import { APP_GUARD } from '@nestjs/core';
import request from 'supertest';
import type { App } from 'supertest/types';
import { ObservabilityModule } from '../src/observability/observability.module';
import { ObservabilityService } from '../src/observability/observability.service';
import { AuthorizationGuard } from '../src/common/authorization/authorization.guard';
import { AuthorizationPolicyService } from '../src/common/authorization/authorization-policy.service';
import { AuthorizationService } from '../src/common/authorization/authorization.service';
import { OwnershipProofInterceptor } from '../src/common/authorization/ownership-proof.interceptor';

/**
 * §33: the audit's finding was that nothing could answer "how long does matching
 * take" or "what is the no-provider rate", and that nine of the top ten failure
 * modes announce themselves with silence.
 *
 * These tests assert the properties that make the scrape target trustworthy
 * rather than merely present. A metrics endpoint that exists but cannot be
 * scraped is the same as no endpoint, so reachability without a credential is the
 * first thing checked — and it is the reason the route is `@Public()`, which in
 * turn is only safe because of the second property: nothing in the output
 * identifies a customer, a booking or an amount.
 */
describe('GET /health/metrics', () => {
  let app: INestApplication<App>;
  let observability: {
    observeBookingCreate(
      seconds: number,
      result: 'created' | 'no_provider',
    ): void;
    observeMatching(seconds: number, stage?: string): void;
    setOutboxBacklog(rows: number): void;
    setDependencyUp(dependency: string, up: boolean): void;
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ObservabilityModule],
      providers: [
        // The real guard, with an authorization service that always denies: this
        // proves `@Public()` is what makes the route reachable, rather than the
        // test simply not exercising auth.
        { provide: APP_GUARD, useClass: AuthorizationGuard },
        {
          provide: AuthorizationPolicyService,
          useClass: AuthorizationPolicyService,
        },
        {
          provide: AuthorizationService,
          useValue: {
            authorizeAccessToken: jest
              .fn()
              .mockRejectedValue(new Error('denied: no token supplied')),
            auditPolicyMissing: jest.fn(),
          },
        },
        { provide: APP_GUARD, useClass: OwnershipProofInterceptor },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useWebSocketAdapter(new WsAdapter(app));
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
    observability = moduleRef.get(ObservabilityService);
  });

  afterAll(async () => {
    await app?.close();
  });

  it('is reachable without a credential', async () => {
    await request(app.getHttpServer()).get('/health/metrics').expect(200);
  });

  it('serves the Prometheus content type and forbids caching', async () => {
    const response = await request(app.getHttpServer())
      .get('/health/metrics')
      .expect(200);

    expect(response.headers['content-type']).toContain('text/plain');
    expect(response.headers['content-type']).toContain('version=0.0.4');
    // A cached reading looks exactly like a live one and is worse than none.
    expect(response.headers['cache-control']).toBe('no-store');
  });

  it('exposes the no-provider rate the audit said was uncomputable', async () => {
    observability.observeBookingCreate(0.2, 'created');
    observability.observeBookingCreate(0.3, 'no_provider');

    const body = (await request(app.getHttpServer()).get('/health/metrics'))
      .text;
    expect(body).toContain('fixnow_bookings_created_total');
    expect(body).toContain('providers_available="false"');
  });

  it('exposes matching duration, which BUG-004 made expensive and invisible', async () => {
    observability.observeMatching(0.012, 'eligibility');

    const body = (await request(app.getHttpServer()).get('/health/metrics'))
      .text;
    expect(body).toContain('fixnow_matching_duration_seconds_bucket');
    expect(body).toContain('stage="eligibility"');
  });

  it('exposes the outbox backlog, which is how a stopped worker announces itself', async () => {
    observability.setOutboxBacklog(271);

    const body = (await request(app.getHttpServer()).get('/health/metrics'))
      .text;
    expect(body).toMatch(/fixnow_outbox_backlog 271/);
  });

  it('exposes dependency health', async () => {
    observability.setDependencyUp('redis', false);

    const body = (await request(app.getHttpServer()).get('/health/metrics'))
      .text;
    expect(body).toContain('fixnow_dependency_up{dependency="redis"} 0');
  });

  it('identifies no customer, booking, payment or contact detail', async () => {
    const body = (await request(app.getHttpServer()).get('/health/metrics'))
      .text;

    // The route is unauthenticated, so this is the guarantee that makes that
    // acceptable. A uuid or a phone number here would be a data breach with a
    // scrape config attached to it.
    expect(body).not.toMatch(
      /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}/i,
    );
    expect(body).not.toMatch(
      /customerId|bookingId|orderId|userId|phone|email|address/i,
    );
  });

  it('emits no label built from a raw request path', async () => {
    // Route *templates* are the label. A raw path would make every distinct
    // booking id its own time series, which is unbounded cardinality — the
    // standard way a metrics endpoint takes down what it monitors.
    await request(app.getHttpServer())
      .get('/api/v1/this-path-does-not-exist-12345')
      .expect(404);

    const body = (await request(app.getHttpServer()).get('/health/metrics'))
      .text;
    expect(body).not.toContain('this-path-does-not-exist-12345');
  });
});
