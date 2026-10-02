import { INestApplication } from '@nestjs/common';
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from '@nestjs/swagger';

/**
 * API-001. The OpenAPI document, built once at bootstrap.
 *
 * Two decisions worth recording, because both were the alternative to the obvious
 * one and both were reached by looking at what this codebase already does.
 *
 * The CLI plugin rather than hand-written decorators. There are 39 controllers
 * and, before this, zero `@Api*` decorators anywhere. Annotating them all by hand
 * is a large diff that would drift immediately: a route added later would carry
 * no documentation and nothing would notice. The plugin reads the same TypeScript
 * the compiler does and derives the paths, parameters and DTO schemas from it, so
 * the document starts as a by-product of the code rather than a parallel
 * description of it. See `nest-cli.json`.
 *
 * `@Public()` and `@RequirePermission()` are translated into the security scheme
 * rather than left implicit. The authorization layer already marks every route as
 * either public or requiring a named permission, and that is exactly the
 * information a consumer of this API needs and cannot infer: whether to send a
 * token, and which role to send it as. Deriving it means a route cannot be
 * documented as public while the guard treats it as protected.
 */
/**
 * Strips the global prefix from the emitted paths.
 *
 * `setGlobalPrefix('api/v1')` is applied by the caller, so `createDocument` emits
 * `/api/v1/auth/login` while the server also serves it at that path - but a
 * consumer pointed at an origin, and the `Try it out` button in Swagger UI, both
 * want `/auth/login`. The prefix is the deployment's, not the API's.
 *
 * It has to happen after the document is built rather than before, because the
 * plugin reads the route table as Nest registered it, prefix included.
 */
function stripGlobalPrefix(
  document: OpenAPIObject,
  globalPrefix: string,
): OpenAPIObject {
  const prefix = globalPrefix.replace(/^\/+|\/+$/g, '');
  if (!prefix) return document;
  const paths = document.paths ?? {};
  const stripped: NonNullable<OpenAPIObject['paths']> = {};
  for (const [path, operations] of Object.entries(paths)) {
    const key = path.replace(new RegExp(`^/${prefix}`), '') || '/';
    stripped[key] = operations;
  }
  return { ...document, paths: stripped };
}

export function buildOpenApiDocument(
  app: INestApplication,
  options: { globalPrefix?: string } = {},
): OpenAPIObject {
  const builder = new DocumentBuilder()
    .setTitle('FixNow API')
    .setDescription(
      [
        'REST surface for the FixNow platform: authentication, bookings,',
        'providers, payments, guarantees, trust and safety, and the realtime',
        'gateway handshake.',
        '',
        'Authentication is a bearer access token obtained from',
        '`POST /api/v1/auth/login` and sent as `Authorization: Bearer <token>`.',
        'Tokens are short-lived; `POST /api/v1/auth/token/refresh` exchanges a',
        'refresh token for a new access token.',
        '',
        'Every route below is marked as public or as requiring a named',
        'permission, and that marking is derived from the same decorator the',
        'authorization guard reads - so it cannot describe a route the guard',
        'would refuse.',
        '',
        'The realtime channel is a WebSocket, not an HTTP route, and so does not',
        'appear in this document. Its path is `/api/v1/realtime`.',
      ].join('\n'),
    )
    .setVersion('1.0.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description:
          'Access token from `POST /api/v1/auth/login`. Send as ' +
          '`Authorization: Bearer <token>`.',
      },
      'bearer',
    )
    .addTag('auth', 'Registration, sign-in, token lifecycle')
    .addTag('bookings', 'Booking lifecycle and dispatch')
    .addTag('providers', 'Provider onboarding and availability')
    .addTag('payments', 'Payments, refunds and escrow')
    .addTag('guarantees', 'Guarantee claims')
    .addTag('trust', 'Trust and safety signals and moderation')
    .addTag('emergency', 'Emergency dispatch')
    .addTag('admin', 'Operations console')
    .addTag('ai', 'Problem classification and recommendations')
    .addTag('health', 'Liveness and readiness')
    // The scrape target is documented for the same reason the readiness probe
    // is: an operator looking for it should find it here rather than guess
    // `/metrics`. It appears in the document even though it is not part of the
    // product contract, because it *is* part of the operational one.
    .addTag('health-metrics', 'Prometheus scrape target');

  const created = SwaggerModule.createDocument(app, builder.build(), {
    // Stable ids, so a generated client's method names do not churn when a
    // handler is renamed. The id also becomes the key the security metadata is
    // looked up by, which is why it is set here rather than defaulted.
    operationIdFactory: (controllerKey: string, methodKey: string) =>
      `${controllerKey}_${methodKey}`,
  });

  applyRouteSecurity(app, created);

  return stripGlobalPrefix(created, options.globalPrefix ?? 'api/v1');
}

/**
 * Applies the bearer requirement per operation, from the authorization metadata
 * the guard already reads.
 *
 * A single global `security` entry would be simpler and wrong in both directions:
 * it would advertise the login endpoint as requiring a token it cannot have, and
 * it would advertise protected routes as open. Neither is a documentation nit -
 * a generated client would stop sending credentials to half the API.
 */
function applyRouteSecurity(
  app: INestApplication,
  document: OpenAPIObject,
): void {
  const securityByOperation = resolveRouteSecurity(app);

  for (const methods of Object.values(document.paths ?? {})) {
    for (const [method, operation] of Object.entries(methods)) {
      if (method === 'parameters' || method === '$ref') continue;
      const target = operation as {
        operationId?: string;
        security?: Array<Record<string, string[]>>;
        'x-required-permission'?: string;
      };

      const route = securityByOperation.get(target.operationId ?? '');
      if (!route) {
        // Unresolvable means the document describes a route the walker did not
        // find. Defaulting to "secured" is the safe direction: a client that
        // sends a token to a public endpoint gets a valid response, whereas one
        // that omits it from a protected endpoint gets a 401.
        target.security = [{ bearer: [] }];
        continue;
      }

      if (route.public) {
        target.security = [];
        continue;
      }

      target.security = [{ bearer: [] }];
      if (route.permission) target['x-required-permission'] = route.permission;
    }
  }
}

interface RouteSecurity {
  public: boolean;
  permission?: string;
}

/**
 * Reads the authorization metadata off every registered route handler.
 *
 * By operation id rather than by URL, and by walking Nest's own container rather
 * than Express's router. The first version of this resolved handlers through
 * `getHttpAdapter().getInstance()._router.stack`, which returns an empty stack
 * until the application has dispatched a request - so at document-build time it
 * found nothing, marked every operation public, and the "exactly the @Public()
 * routes" test passed with zero public routes. Reaching into `_router` is also
 * private Express API, which is a poor foundation for a security claim.
 *
 * Nest's container is public API and is populated at init, so this is both correct
 * and stable.
 */
function resolveRouteSecurity(
  app: INestApplication,
): Map<string, RouteSecurity> {
  const resolved = new Map<string, RouteSecurity>();
  // `container` is not on the `INestApplication` interface but every concrete
  // adapter exposes it, and it is the public, supported way to enumerate the
  // registered providers. The alternative - reading Express's private `_router` -
  // is both unofficial and, as this function's own history shows, empty at the
  // moment the document is built.
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
    // `module.controllers`, not `module.providers`. Nest keeps the two in
    // separate maps, and a controller registered through a module is in neither
    // providers' instance list nor reachable from it - iterating `providers` here
    // found 363 entries and zero controllers, which is why every operation was
    // being marked secured on the first attempt and the metadata lookup came back
    // empty. The asymmetry is easy to miss because providers are the more
    // familiar collection and the map is right there.
    for (const [, wrapper] of module.controllers ?? new Map()) {
      const instance = wrapper.instance ?? null;
      const metatype = (instance as { constructor?: { name: string } } | null)
        ?.constructor;
      if (!instance || typeof metatype !== 'function') continue;
      const prototype = Object.getPrototypeOf(instance) as object | null;
      if (!prototype) continue;

      for (const name of Object.getOwnPropertyNames(prototype)) {
        if (name === 'constructor') continue;
        const descriptor = Object.getOwnPropertyDescriptor(prototype, name);
        if (!descriptor || typeof descriptor.value !== 'function') continue;
        // The document's operation ids are built from the class name and the
        // method name, so the metadata is read from the function the decorator
        // was applied to and matched on the same pair.
        //
        // `Reflect.getMetadata` is typed as returning `any`, which would make
        // both reads unchecked values. Reading it through a typed signature
        // keeps the `=== true` and `typeof === 'string'` narrowing meaningful —
        // otherwise "the decorator is absent" and "the decorator returned
        // nonsense" are indistinguishable at the call site.
        const handler = descriptor.value as (...args: never[]) => unknown;
        const isPublic: unknown = Reflect.getMetadata(
          'fixnow.authorization.public',
          handler,
        );
        const permission: unknown = Reflect.getMetadata(
          'fixnow.authorization.permission',
          handler,
        );
        resolved.set(`${metatype.name}_${name}`, {
          public: isPublic === true,
          permission: typeof permission === 'string' ? permission : undefined,
        });
      }
    }
  }

  return resolved;
}

/** The prefix the application was created with, read from the running app. */
export function resolveGlobalPrefix(app: INestApplication): string {
  const adapter = app.getHttpAdapter() as unknown as {
    getGlobalPrefix?(): string;
  };
  return adapter.getGlobalPrefix?.() ?? '';
}
