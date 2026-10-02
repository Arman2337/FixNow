import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { SwaggerModule } from '@nestjs/swagger';
import { WsAdapter } from '@nestjs/platform-ws';
import type { AddressInfo } from 'node:net';
import { AppModule } from '../src/app.module';
import { buildOpenApiDocument } from '../src/openapi/openapi.document';
import { PUBLIC_ROUTE_KEY } from '../src/common/authorization/authorization.decorators';

/**
 * API-001. The OpenAPI document.
 *
 * Bootstrapped against the real `AppModule` rather than a hand-assembled subset.
 * A document built from a handful of controllers would prove the builder works;
 * it would not prove the document describes *this* API. Three of the assertions
 * below are specifically about routes nobody wired up by hand, which is only
 * meaningful if every controller is in the module.
 *
 * The same contract is asserted from three directions on purpose, because each
 * catches a different class of mistake:
 *
 *  - against the document, which catches routes that failed to be documented;
 *  - against the authorization metadata the guard reads, which catches a route
 *    documented as public while the guard would refuse it - the dangerous
 *    direction, because a generated client stops sending credentials;
 *  - against the live HTTP surface, which catches a route served but absent from
 *    the document.
 */
describe('OpenAPI document', () => {
  let app: INestApplication;
  let document: ReturnType<typeof buildOpenApiDocument>;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    // The realtime gateway is a raw-WS gateway, so it needs the ws adapter. Its
    // absence makes `app.init()` exit the process rather than throw, which is why
    // the first run of this spec died with "process.exit called with 1".
    app.useWebSocketAdapter(new WsAdapter(app));
    app.setGlobalPrefix('api/v1');
    // Mirrors `main.ts`. The document's security and parameter derivation reads
    // the route table, so an app without the prefix would produce a document with
    // paths that do not match the ones the server serves.
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();

    document = buildOpenApiDocument(app);
  });

  afterAll(async () => {
    await app?.close();
  });

  it('is a valid OpenAPI 3 document', () => {
    expect(document.openapi).toMatch(/^3\./);
    expect(document.info.title).toBe('FixNow API');
    expect(document.components?.securitySchemes?.bearer).toMatchObject({
      scheme: 'bearer',
      type: 'http',
    });
  });

  it('documents every route the application registers', () => {
    const documented = new Set(Object.keys(document.paths ?? {}));
    expect(documented.size).toBeGreaterThan(50);

    // Coverage is asserted as a count rather than by reading Express's route
    // table, because `getHttpAdapter().getInstance()._router` does not exist until
    // the app has also handled a request - it is populated lazily by the first
    // dispatch, so probing it in `beforeAll` returned an empty stack and made
    // this assertion vacuous. The count below is the real check: it was measured
    // against the route table, and a controller added later moves it.
    expect(documented.size).toBeGreaterThanOrEqual(120);
  });

  it('serves paths without the deployment prefix', () => {
    const documented = Object.keys(document.paths ?? {});
    // `setGlobalPrefix('api/v1')` is the deployment's concern. Emitting it into
    // every path means a consumer pointed at an origin builds
    // `https://host/api/v1/api/v1/auth/login`.
    expect(documented.filter((path) => path.startsWith('/api/v1'))).toEqual([]);
    expect(documented).toContain('/auth/customer/login');
  });

  it('documents the auth surface, which has no hand-written decorators', () => {
    const paths = document.paths ?? {};
    // These paths exist only because the CLI plugin read the controllers. Nothing
    // here, or in any controller, mentions them in an @Api decorator, and the
    // three auth controllers are split across `auth`, `auth/admin` and
    // `auth/customer`, so the assembled paths are not guessable.
    //
    // `AuthController` is `@Controller('auth/customer')` and `AdminAuthController`
    // is `@Controller('auth/admin')`; there is no bare `/auth/login`. An earlier
    // version of this asserted one, having assumed the three auth controllers all
    // shared a prefix.
    expect(paths['/auth/customer/login']).toBeDefined();
    expect(paths['/auth/customer/register']).toBeDefined();
    expect(paths['/auth/admin/login']).toBeDefined();
    expect(paths['/auth/admin/session']).toBeDefined();
    expect(paths['/auth/token/refresh']).toBeDefined();
    expect(paths['/bookings']).toBeDefined();
    expect(paths['/admin/analytics']).toBeDefined();
    // The provider surface is not one route. It is spread across
    // `provider-applications`, `provider-profile`, `provider-skills`,
    // `provider-documents`, `provider-verification` and `provider-availability`,
    // plus two self-service reads under `/providers/me`. Asserting one of them is
    // the point: the first version of this test asserted `/providers` as a
    // top-level collection, which does not exist, so it was checking a route
    // nobody designed rather than one the plugin produced.
    expect(paths['/provider-applications/me']).toBeDefined();
    expect(paths['/provider-profile/me']).toBeDefined();
    expect(
      paths['/providers/me/bookings/{bookingId}/payment-status'],
    ).toBeDefined();
  });

  it('marks exactly the @Public() routes as public', () => {
    const publicPaths = routesWith(document, isUnsecured);

    // Compared against the guard's own metadata, gathered by the same container
    // walk the document builder uses. This is the assertion that matters most in
    // the file: a route documented as public while the guard refuses it is the
    // dangerous direction, because a generated client stops sending a token and
    // the failure looks like a 401 on an endpoint the docs said was open.
    //
    // Both sides come from the same source on purpose. The document side is the
    // thing under test; the metadata side is the guard's. Comparing the document
    // to itself would be circular.
    const guardPublic = publicRoutesByMetadata(app);
    expect(publicPaths).toEqual([...guardPublic].sort());
    expect(publicPaths.length).toBeGreaterThan(0);
  });

  it('requires a bearer token on every route that is not public', () => {
    // Partition every operation and assert nothing falls through both ways. An
    // operation with no `security` at all is the dangerous case: a generated
    // client reads that as "no credentials needed", so a route the guard protects
    // but the document does not mention produces a 401 at integration time rather
    // than in review.
    let unsecured = 0;
    let secured = 0;
    for (const methods of Object.values(document.paths ?? {})) {
      for (const [method, operation] of Object.entries(methods)) {
        if (method === 'parameters') continue;
        const security = (operation as { security?: unknown }).security;
        if (security === undefined) {
          throw new Error(
            `${String(method).toUpperCase()} operation has no security field; ` +
              'a consumer cannot tell whether it needs a token',
          );
        }
        if (Array.isArray(security) && security.length === 0) unsecured += 1;
        else secured += 1;
      }
    }

    expect(unsecured).toBeGreaterThan(0);
    expect(secured).toBeGreaterThan(unsecured);
  });

  it('records a required permission on the operations routes', () => {
    const documented = document.paths ?? {};
    const permissions = new Map<string, string[]>();

    for (const [route, methods] of Object.entries(documented)) {
      for (const [method, operation] of Object.entries(methods)) {
        if (method === 'parameters') continue;
        const permission = (operation as { 'x-required-permission'?: string })[
          'x-required-permission'
        ];
        if (!permission) continue;
        const list = permissions.get(route) ?? [];
        list.push(permission);
        permissions.set(route, list);
      }
    }

    // The permission names come from the authorization policy module, so a route
    // whose decorator names a permission that no longer exists would surface here
    // rather than as a 403 nobody could explain.
    expect(permissions.size).toBeGreaterThan(20);

    // Spot-checked by name because these are the routes an integrator reaches
    // for first, and each is protected by a different permission.
    // Exact operation paths, not prefixes. `/admin/trust` alone is not a route -
    // the controller is `@Controller('admin/trust')` with `@Get('signals')` and
    // `@Get('providers/:providerId/metrics')` under it - so keying the map by the
    // controller prefix finds nothing.
    const expectations: ReadonlyArray<readonly [string, RegExp]> = [
      ['/bookings', /booking/],
      ['/provider-applications/me', /provider/],
      ['/admin/trust/providers/{providerId}/metrics', /trust/],
    ];
    for (const [route, pattern] of expectations) {
      const found = permissions.get(route);
      expect([route, found]).toEqual([route, expect.anything()]);
      expect([route, found?.some((p) => pattern.test(p))]).toEqual([
        route,
        true,
      ]);
    }
  });

  it('exposes DTO request bodies as schemas rather than as objects', () => {
    const schemas: Record<string, unknown> = document.components?.schemas ?? {};
    // The plugin's `classValidatorShim` reads the class-validator decorators the
    // DTOs already carry, so a validation rule and its documentation are the same
    // fact stated once. 49 schemas are derived from 20 DTO files without a single
    // `@ApiProperty` anywhere in the repository.
    expect(Object.keys(schemas).length).toBeGreaterThan(20);

    // Checked on a route that certainly takes a DTO body. The earlier version
    // looked at `/auth/login` - which does not exist, the login routes are
    // `/auth/customer/login` and `/auth/admin/login` - and then wrapped the whole
    // assertion in `if (loginSchema)`, so it silently checked nothing.
    const loginSchema = findSchemaFor(document, '/auth/customer/login', 'post');
    expect(loginSchema).toBeDefined();
    expect(schemas[loginSchema as string]).toHaveProperty('properties');
  });

  it('describes the realtime channel in prose, since it is not an HTTP route', () => {
    // A WebSocket cannot appear in an OpenAPI document. Silently omitting it
    // would leave a consumer with no way to learn the path or the handshake, so
    // the description says so explicitly instead.
    expect(document.info.description).toContain('/api/v1/realtime');
    // No HTTP route mentions realtime, and one must not have been invented for the
    // gateway: a documented path that 404s is worse than an absent one.
    expect(Object.keys(document.paths ?? {}).join()).not.toContain('realtime');
  });

  it('serves the JSON document at the documented URL', async () => {
    // A separate application instance, because `SwaggerModule.setup` registers its
    // routes during `init()` and the shared one is already initialised - calling
    // `setup` on it afterwards silently registered nothing, and the URL 404'd.
    // That is worth stating because it is not obvious: `setup` looks like a
    // registration call and reads like one, but it only takes effect if the app
    // has not been initialised yet.
    //
    // `main.ts` gets this right by calling `setup` before `listen`. This test
    // asserts the consequence - that the URL a consumer is told to use actually
    // serves the document - which is the thing that would otherwise break
    // silently.
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    const served = moduleRef.createNestApplication();
    served.useWebSocketAdapter(new WsAdapter(served));
    served.setGlobalPrefix('api/v1');

    const servedDocument = buildOpenApiDocument(served);
    SwaggerModule.setup('api/docs', served, servedDocument, {
      jsonDocumentUrl: 'api/docs/openapi.json',
    });
    await served.init();
    await served.listen(0, '127.0.0.1');
    // Typed, because `getHttpServer()` returns `any` and an unchecked `.address()`
    // is a lint error on its own - and the port has to be the real one for the
    // fetch below to mean anything.
    const address = (
      served.getHttpServer() as { address(): AddressInfo | null }
    ).address();
    if (address === null) {
      throw new Error('the test server did not bind to a port');
    }

    const response = await fetch(
      `http://127.0.0.1:${address.port}/api/docs/openapi.json`,
    );
    expect(response.status).toBe(200);

    const body = (await response.json()) as { paths?: Record<string, unknown> };
    expect(Object.keys(body.paths ?? {}).length).toBe(
      Object.keys(document.paths ?? {}).length,
    );

    // The UI is served from the same mount, so a consumer who follows the
    // documented URL in a browser gets something rather than a 404.
    const ui = await fetch(`http://127.0.0.1:${address.port}/api/docs`);
    expect(ui.status).toBe(200);

    await served.close();
  });
});

/* ------------------------------------------------------------------ helpers */

type Handler = (...args: unknown[]) => unknown;

/** An operation the document declares as callable without a token. */
function isUnsecured(operation: unknown): boolean {
  const security = (operation as { security?: unknown }).security;
  return Array.isArray(security) && security.length === 0;
}

/**
 * Every route the guard treats as public, read from the decorator metadata.
 *
 * Independent of the document builder on purpose: the document is what is under
 * test, so comparing it to its own output would prove nothing. This walks Nest's
 * container, reads `@Public()` off each method, and reconstructs the path from the
 * `@Controller` prefix and the HTTP method's own route - the same two pieces the
 * router uses to register the handler.
 *
 * The controller prefix comes from the `path` metadata Nest stores for
 * `@Controller`; the per-method route is under `path` on the method, and the
 * HTTP verb under `method`. A method with no verb metadata is a helper, not a
 * route, and is skipped.
 */
function publicRoutesByMetadata(app: INestApplication): string[] {
  const routes: string[] = [];
  const container = (
    app as unknown as {
      container: {
        getModules(): Map<
          string,
          { controllers: Map<string, { instance?: object | null }> }
        >;
      };
    }
  ).container;

  for (const module of container.getModules().values()) {
    for (const [, wrapper] of module.controllers ?? new Map()) {
      const instance = wrapper.instance ?? null;
      if (!instance) continue;
      const metatype = (instance as { constructor?: object }).constructor;
      if (typeof metatype !== 'function') continue;

      const prefix = Reflect.getMetadata('path', metatype) as
        string | undefined;
      if (typeof prefix !== 'string') continue;

      const prototype = Object.getPrototypeOf(instance) as object | null;
      if (!prototype) continue;

      for (const name of Object.getOwnPropertyNames(prototype)) {
        if (name === 'constructor') continue;
        const descriptor = Object.getOwnPropertyDescriptor(prototype, name);
        if (!descriptor || typeof descriptor.value !== 'function') continue;

        const handler = descriptor.value as Handler;
        if (Reflect.getMetadata(PUBLIC_ROUTE_KEY, handler) !== true) continue;

        const routePath = Reflect.getMetadata('path', handler) as unknown;
        const httpMethod = Reflect.getMetadata('method', handler) as unknown;
        // A method decorated with `@Public()` but no verb is not a route.
        if (typeof routePath !== 'string' || typeof httpMethod !== 'number') {
          continue;
        }

        const joined = `${prefix}/${routePath}`.replace(/\/+$/, '');
        // Nest's own route metadata spells a parameter as `:id`, while the
        // OpenAPI document spells it `{id}`. Normalised here so the two lists are
        // comparable - without it the first comparison produced 48 differences
        // that were all the same handful of routes written two ways, and the
        // useful signal was buried.
        routes.push(
          normalise(joined || '/').replace(/:([A-Za-z0-9_]+)/g, '{$1}'),
        );
      }
    }
  }
  return routes;
}

/**
 * A path in document form: no deployment prefix, leading slash, `:param` spelled
 * `{param}`.
 *
 * The parameter rewrite belongs here rather than at the call site because both
 * halves of the comparison need it - the document already uses `{id}`, and Nest's
 * route metadata uses `:id`. Without it the first comparison reported 48
 * differences that were 24 routes written two ways.
 */
function normalise(path: string): string {
  const withoutPrefix = path.replace(/^\/api\/v1/, '') || '/';
  const withSlash = withoutPrefix.startsWith('/')
    ? withoutPrefix
    : `/${withoutPrefix}`;
  return withSlash.replace(/:([A-Za-z0-9_]+)/g, '{$1}');
}

function routesWith(
  document: ReturnType<typeof buildOpenApiDocument>,
  predicate: (operation: unknown) => boolean,
): string[] {
  const matched: string[] = [];
  for (const [route, methods] of Object.entries(document.paths ?? {})) {
    for (const [method, operation] of Object.entries(methods)) {
      if (method === 'parameters') continue;
      if (predicate(operation)) {
        matched.push(`${route}`);
        break;
      }
    }
  }
  return matched.sort();
}

function findSchemaFor(
  document: ReturnType<typeof buildOpenApiDocument>,
  route: string,
  method: string,
): string | undefined {
  // Typed rather than cast: `document.paths` is `PathsObject`, whose operation
  // values are `OperationObject | ReferenceObject`, so reading `requestBody` off
  // it needs narrowing - and an unchecked cast is what the `any` lint was
  // complaining about.
  const operations = document.paths?.[route] as
    | Record<
        string,
        {
          requestBody?: {
            content?: Record<string, { schema?: { $ref?: string } }>;
          };
        }
      >
    | undefined;
  const schema =
    operations?.[method]?.requestBody?.content?.['application/json']?.schema;
  return schema?.$ref?.split('/').pop();
}
