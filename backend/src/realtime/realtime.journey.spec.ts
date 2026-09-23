import { ConfigService } from '@nestjs/config';
import type { IncomingMessage } from 'node:http';
import { WebSocket } from 'ws';
import type { Cache } from 'cache-manager';
import { DataSource, In } from 'typeorm';
import { AuthorizationService } from '../common/authorization/authorization.service';
import { Booking } from '../bookings/domain/booking.entity';
import { ProviderAvailabilityEntity } from '../providers/availability/provider-availability.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { LocationService } from '../location/location.service';
import { EtaAdapter } from './eta-adapter';
import { RouteAdapter } from './route-adapter';
import { BookingProjectionService } from './booking-projection.service';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeTelemetryService } from './realtime-telemetry.service';

const PROVIDER_ID = '00000000-0000-4000-8000-000000000002';
const CUSTOMER_ID = '00000000-0000-4000-8000-000000000001';
const BOOKING_ID = '00000000-0000-4000-8000-000000000010';

type Frame = Record<string, unknown>;

const sentFrames = (send: jest.Mock): Frame[] =>
  send.mock.calls.map(([raw]) => JSON.parse(raw as string) as Frame);

const lastFrame = (send: jest.Mock, type: string): Frame | undefined =>
  [...sentFrames(send)].reverse().find((frame) => frame.type === type);

describe('Realtime live-journey pipeline', () => {
  let gateway: RealtimeGateway;
  let registry: RealtimeConnectionRegistry;
  let bookingRow: Booking;
  let providerSend: jest.Mock;
  let customerSend: jest.Mock;
  let providerClient: WebSocket;
  let customerClient: WebSocket;

  const connect = async (
    client: WebSocket,
    token: string,
    userId: string,
    roles: string[],
  ): Promise<void> => {
    registry.registerPending(client, '127.0.0.1');
    await gateway.onMessage(
      client,
      Buffer.from(JSON.stringify({ type: 'authenticate', accessToken: token })),
      false,
    );
    expect(lastFrame(client['send'] as jest.Mock, 'ready')).toBeDefined();
    void userId;
    void roles;
  };

  const subscribe = async (
    client: WebSocket,
    requestId: string,
  ): Promise<void> => {
    await gateway.onMessage(
      client,
      Buffer.from(
        JSON.stringify({
          type: 'subscribe',
          channel: 'booking',
          resourceId: BOOKING_ID,
          requestId,
        }),
      ),
      false,
    );
    expect(lastFrame(client['send'] as jest.Mock, 'subscribed')).toBeDefined();
  };

  const publishProviderLocation = async (): Promise<void> => {
    await gateway.onMessage(
      providerClient,
      Buffer.from(JSON.stringify({ type: 'presence-update', online: true })),
      false,
    );
    await gateway.onMessage(
      providerClient,
      Buffer.from(
        JSON.stringify({
          type: 'location-consent',
          bookingId: BOOKING_ID,
          granted: true,
          noticeVersion: '2026-08-13',
        }),
      ),
      false,
    );
    await gateway.onMessage(
      providerClient,
      Buffer.from(
        JSON.stringify({
          type: 'location-update',
          bookingId: BOOKING_ID,
          sequence: 1,
          capturedAt: new Date().toISOString(),
          latitude: 23.0225,
          longitude: 72.5714,
          accuracyMeters: 12,
        }),
      ),
      false,
    );
    expect(
      lastFrame(providerSend, 'location-ack'),
    ).toBeDefined();
  };

  beforeEach(() => {
    jest.clearAllMocks();
    bookingRow = Object.assign(new Booking(), {
      id: BOOKING_ID,
      customerId: CUSTOMER_ID,
      providerId: PROVIDER_ID,
      status: BookingStatus.EN_ROUTE,
      locationLat: 23.02,
      locationLng: 72.57,
      version: 7,
    }) as Booking;

    const cacheValues = new Map<string, unknown>();
    const cache = {
      get: async (key: string) => cacheValues.get(key),
      set: async (key: string, value: unknown) => {
        cacheValues.set(key, value);
      },
      del: async (key: string) => {
        cacheValues.delete(key);
      },
    } as unknown as Cache;

    const bookingRepository = {
      findOne: jest.fn(async () => bookingRow),
      find: jest.fn(async () => []),
    };
    const availabilityRepository = {
      findOne: jest.fn(async () => ({
        status: 'online',
        statusExpiresAt: new Date(Date.now() + 3_600_000),
      })),
    };
    const dataSource = {
      getRepository: jest.fn((entity: unknown) =>
        entity === Booking ? bookingRepository : availabilityRepository,
      ),
    } as unknown as DataSource;

    const config = {
      get: (_key: string, fallback?: unknown) => fallback,
    } as unknown as ConfigService;

    const authorization = {
      authorizeAccessToken: jest.fn(async (token: string) =>
        token === 'provider-token'
          ? {
              userId: PROVIDER_ID,
              sessionId: 'provider-session',
              roles: ['verified_provider'],
            }
          : {
              userId: CUSTOMER_ID,
              sessionId: 'customer-session',
              roles: ['customer'],
            },
      ),
    } as unknown as AuthorizationService;

    const routes = {
      route: jest.fn(async () => ({
        distanceMeters: 4200,
        durationSeconds: 600,
        coordinates: [
          [72.5714, 23.0225],
          [72.5791, 23.0276],
        ],
      })),
    } as unknown as RouteAdapter;
    const eta = {
      estimate: jest.fn(async () => ({
        estimatedMinutes: 10,
        source: 'test',
      })),
    } as unknown as EtaAdapter;

    registry = new RealtimeConnectionRegistry();
    const projections = new BookingProjectionService(registry, eta, routes);
    const location = new LocationService(dataSource, cache, config);
    gateway = new RealtimeGateway(
      authorization,
      registry,
      new RealtimeTelemetryService(),
      config,
      location,
      dataSource,
      projections,
    );

    providerSend = jest.fn();
    customerSend = jest.fn();
    providerClient = {
      readyState: WebSocket.OPEN,
      send: providerSend,
      close: jest.fn(),
      on: jest.fn(),
      ping: jest.fn(),
    } as unknown as WebSocket;
    customerClient = {
      readyState: WebSocket.OPEN,
      send: customerSend,
      close: jest.fn(),
      on: jest.fn(),
      ping: jest.fn(),
    } as unknown as WebSocket;
  });

  it('delivers the provider journey to a customer already watching the booking', async () => {
    await connect(providerClient, 'provider-token', PROVIDER_ID, [
      'verified_provider',
    ]);
    await connect(customerClient, 'customer-token', CUSTOMER_ID, ['customer']);
    await subscribe(providerClient, 'p1');
    await subscribe(customerClient, 'c1');

    await publishProviderLocation();

    const projection = lastFrame(customerSend, 'booking.projection-updated.v1');
    expect(projection).toBeDefined();
    const data = projection!['data'] as Frame;
    expect(data['locationAvailability']).toBe('live');
    expect(data['status']).toBe(BookingStatus.EN_ROUTE);
    expect(data['sequence']).toBe(7);
    const point = data['location'] as Frame;
    expect(point).toMatchObject({
      latitude: 23.0225,
      longitude: 72.5714,
      accuracyMeters: 12,
    });
    // The mobile parser requires these exact keys and string dates.
    expect(typeof point['capturedAt']).toBe('string');
    expect(typeof point['receivedAt']).toBe('string');
    const route = data['route'] as Frame;
    expect((route['coordinates'] as unknown[]).length).toBe(2);
    expect((data['eta'] as Frame)['estimatedMinutes']).toBe(10);
  });

  it('snapshots the cached journey to a customer who opens tracking mid-route', async () => {
    await connect(providerClient, 'provider-token', PROVIDER_ID, [
      'verified_provider',
    ]);
    await subscribe(providerClient, 'p1');
    await publishProviderLocation();

    // The customer opens the tracking screen only after the journey began.
    await connect(customerClient, 'customer-token', CUSTOMER_ID, ['customer']);
    await subscribe(customerClient, 'c1');

    const projection = lastFrame(customerSend, 'booking.projection-updated.v1');
    expect(projection).toBeDefined();
    const data = projection!['data'] as Frame;
    expect(data['locationAvailability']).toBe('live');
    expect((data['location'] as Frame)['latitude']).toBe(23.0225);
  });
});
