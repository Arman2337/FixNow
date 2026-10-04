import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { App } from 'supertest/types';
import { BookingsModule } from './bookings.module';
import { BookingsController } from './bookings.controller';
import { SchedulesController } from './schedules.controller';
import { BookingsService } from './bookings.service';
import { SchedulesService } from './schedules.service';
import { MatchingService } from '../matching/matching.service';
import { ProviderCapacityService } from '../providers/availability/provider-capacity.service';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

/**
 * The route-shadowing regression, asserted against a real Express router.
 *
 * `GET /api/v1/bookings/schedules` used to be captured by `BookingsController`'s
 * `@Get(':id')`, which handed the literal string "schedules" to a uuid column.
 * PostgreSQL raised `invalid input syntax for type uuid: "schedules"`, the
 * request surfaced as a 500, and the mobile client rendered that as "Repeating
 * services are unavailable" — a working feature reported as broken because the
 * request was matched by the wrong controller.
 *
 * Asserting on the module's `controllers` array alone would not catch this, and
 * neither would asserting on the controller decorators. The array order only
 * matters because Nest registers routes in it and Express matches in
 * registration order, so both controllers are mounted here, in the order the
 * real module lists them, and the requests are actually issued over HTTP.
 *
 * Deliberately does not boot `AppModule` or stand up a database: this is about
 * route matching, and the services the routes call are replaced.
 */
describe('bookings route resolution', () => {
  // `INestApplication<App>` rather than bare `INestApplication`: `getHttpServer()`
  // is typed `any` without the server type argument, and supertest wants an
  // `App`. This is how the other HTTP-level specs in the repo declare it.
  let app: INestApplication<App>;

  const principal = {
    userId: '11111111-1111-4111-8111-111111111111',
    sessionId: 'session-1',
    roles: [],
  };

  const schedulesService = {
    listSelf: jest.fn().mockResolvedValue([]),
  };
  const bookingsService = {
    getBookingForUser: jest.fn(),
  };

  beforeAll(async () => {
    // The controllers are taken from `BookingsModule`'s own metadata, in the
    // order it registers them — not written out here. Hardcoding the order in
    // the test would make every routing assertion below pass regardless of what
    // the module does, which is the opposite of what this file is for: an earlier
    // draft listed `[SchedulesController, BookingsController]` literally and
    // still passed with the module's order reverted. Reading the real order is
    // what makes these tests reproduce the original shadowing.
    const registered = Reflect.getMetadata(
      'controllers',
      BookingsModule,
    ) as (new (...args: never[]) => unknown)[];
    const controllers = registered.filter(
      (controller) =>
        controller === SchedulesController || controller === BookingsController,
    );
    expect(controllers).toHaveLength(2);

    const moduleRef = await Test.createTestingModule({
      controllers,
      providers: [
        { provide: SchedulesService, useValue: schedulesService },
        { provide: BookingsService, useValue: bookingsService },
        {
          provide: MatchingService,
          useValue: { isProviderEligible: jest.fn() },
        },
        { provide: ProviderCapacityService, useValue: {} },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    // Stands in for the authorization guard. The guard is registered globally
    // by `AuthModule`, which is not booted here, and both handlers read
    // `req.authorizationPrincipal` — so without this the routes would be
    // matched correctly and then throw on an undefined principal, which is a
    // failure about the harness rather than about the thing under test.
    app.use((req: AuthorizedRequest, _res: unknown, next: () => void) => {
      req.authorizationPrincipal = principal;
      next();
    });
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  beforeEach(() => jest.clearAllMocks());

  it('routes GET /bookings/schedules to the schedules controller, not getBooking', async () => {
    await request(app.getHttpServer()).get('/api/v1/bookings/schedules');

    expect(schedulesService.listSelf).toHaveBeenCalledWith(
      principal.userId,
      principal,
    );
    // The assertion that carries the regression: this path used to reach
    // getBooking, and the uuid cast error is what the caller saw as a 500.
    expect(bookingsService.getBookingForUser).not.toHaveBeenCalled();
  });

  it('answers an empty schedule list with 200 and an array', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/v1/bookings/schedules')
      .expect(200);

    expect(response.body).toEqual([]);
  });

  it('rejects a non-uuid path segment with 400 instead of letting it reach postgres', async () => {
    // The ParseUUIDPipe half of the fix. Without it, `not-a-uuid` reached
    // `WHERE id = 'not-a-uuid'` and came back as a 500.
    await request(app.getHttpServer())
      .get('/api/v1/bookings/not-a-uuid')
      .expect(400);

    expect(bookingsService.getBookingForUser).not.toHaveBeenCalled();
  });

  it('still routes a real uuid to getBooking', async () => {
    const bookingId = '22222222-2222-4222-8222-222222222222';
    bookingsService.getBookingForUser.mockResolvedValue({
      id: bookingId,
      customerId: principal.userId,
      providerId: principal.userId,
      status: 'ASSIGNED',
      version: 1,
      // The presenter reads these, so a partial entity fails on a missing
      // timestamp rather than on the thing this test is about.
      createdAt: new Date('2026-08-12T00:00:00.000Z'),
      updatedAt: new Date('2026-08-12T00:00:00.000Z'),
    });

    await request(app.getHttpServer())
      .get(`/api/v1/bookings/${bookingId}`)
      .expect(200);

    expect(bookingsService.getBookingForUser).toHaveBeenCalledWith(
      bookingId,
      principal.userId,
    );
  });

  it('registers the schedules routes before the booking :id routes', () => {
    const controllers = Reflect.getMetadata('controllers', BookingsModule) as {
      name: string;
    }[];
    const names = controllers.map((controller) => controller.name);

    // Documented in `bookings.module.ts`: this ordering IS the fix, and it is
    // the part a later edit is most likely to undo by accident — putting the
    // controllers back into a "logical" order breaks the feature with no
    // compiler error. This is the assertion that catches it.
    expect(names.indexOf('SchedulesController')).toBeGreaterThanOrEqual(0);
    expect(names.indexOf('SchedulesController')).toBeLessThan(
      names.indexOf('BookingsController'),
    );
  });
});
