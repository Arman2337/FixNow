import {
  ForbiddenException,
  INestApplication,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WsAdapter } from '@nestjs/platform-ws';
import { Test } from '@nestjs/testing';
import type { AddressInfo } from 'node:net';
import { WebSocket } from 'ws';
import { AuthorizationService } from '../src/common/authorization/authorization.service';
import { PERMISSIONS } from '../src/common/authorization/permission-policies';
import {
  REALTIME_CLOSE,
  REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL,
} from '../src/realtime/realtime.constants';
import { RealtimeConnectionRegistry } from '../src/realtime/realtime-connection-registry.service';
import { RealtimeGateway } from '../src/realtime/realtime.gateway';
import { RealtimeTelemetryService } from '../src/realtime/realtime-telemetry.service';
import { LocationService } from '../src/location/location.service';
import { DataSource } from 'typeorm';
import { BookingProjectionService } from '../src/realtime/booking-projection.service';

const USER_ID = '00000000-0000-4000-8000-000000000001';
const OTHER_USER_ID = '00000000-0000-4000-8000-000000000002';

describe('authenticated WebSocket infrastructure', () => {
  let app: INestApplication;
  let url: string;
  let authorizeAccessToken: jest.Mock;
  const clients = new Set<WebSocket>();

  beforeEach(async () => {
    authorizeAccessToken = jest.fn(
      (token: string, permission: string, context?: { ownerId?: string }) => {
        if (token === 'dependency-failure') {
          return Promise.reject(new Error('database unavailable'));
        }
        if (token !== 'valid-access-token') {
          return Promise.reject(new UnauthorizedException());
        }
        if (
          permission === PERMISSIONS.realtimeSubscribeSelf &&
          context?.ownerId !== USER_ID
        ) {
          return Promise.reject(new ForbiddenException());
        }
        return Promise.resolve({
          userId: USER_ID,
          sessionId: '00000000-0000-4000-8000-000000000010',
          roles: ['customer'],
        });
      },
    );
    const moduleRef = await Test.createTestingModule({
      providers: [
        RealtimeGateway,
        RealtimeConnectionRegistry,
        RealtimeTelemetryService,
        {
          provide: LocationService,
          useValue: {
            updatePresence: jest.fn(),
            updateConsent: jest.fn(),
            ingestLocation: jest.fn(),
          },
        },
        {
          provide: DataSource,
          useValue: { getRepository: jest.fn() },
        },
        {
          provide: BookingProjectionService,
          useValue: { publishLocation: jest.fn() },
        },
        {
          provide: AuthorizationService,
          useValue: { authorizeAccessToken },
        },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) =>
              key === 'REALTIME_ALLOWED_ORIGINS'
                ? 'https://app.fixnow.test'
                : undefined,
          },
        },
      ],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useWebSocketAdapter(new WsAdapter(app));
    await app.listen(0, '127.0.0.1');
    const httpServer = app.getHttpServer() as {
      address(): AddressInfo | string | null;
    };
    const address = httpServer.address() as AddressInfo;
    url = `ws://127.0.0.1:${address.port}/realtime`;
  });

  afterEach(async () => {
    for (const client of clients) client.terminate();
    clients.clear();
    await app.close();
  });

  it('authenticates from the first private frame and authorizes only the caller account channel', async () => {
    const client = await connect();
    client.send(
      JSON.stringify({
        type: 'authenticate',
        accessToken: 'valid-access-token',
      }),
    );
    await expect(nextFrame(client)).resolves.toMatchObject({
      type: 'ready',
      protocolVersion: 1,
      resumeSupported: false,
    });

    client.send(
      JSON.stringify({
        type: 'subscribe',
        requestId: 'own',
        channel: 'account',
        resourceId: USER_ID,
      }),
    );
    await expect(nextFrame(client)).resolves.toMatchObject({
      type: 'subscribed',
      requestId: 'own',
      resourceId: USER_ID,
    });

    client.send(
      JSON.stringify({
        type: 'subscribe',
        requestId: 'other',
        channel: 'account',
        resourceId: OTHER_USER_ID,
      }),
    );
    await expect(nextFrame(client)).resolves.toEqual({
      type: 'subscription-denied',
      requestId: 'other',
      code: 'not-authorized',
    });
    expect(authorizeAccessToken).toHaveBeenLastCalledWith(
      'valid-access-token',
      PERMISSIONS.realtimeSubscribeSelf,
      { ownerId: OTHER_USER_ID },
    );
  });

  it('rejects invalid authentication without echoing the credential', async () => {
    const client = await connect();
    client.send(
      JSON.stringify({ type: 'authenticate', accessToken: 'invalid-secret' }),
    );
    const closed = await nextClose(client);
    expect(closed.code).toBe(REALTIME_CLOSE.authenticationRequired);
    expect(closed.reason).not.toContain('invalid-secret');
  });

  it('fails safely when the authoritative authentication dependency is unavailable', async () => {
    const client = await connect();
    client.send(
      JSON.stringify({
        type: 'authenticate',
        accessToken: 'dependency-failure',
      }),
    );
    await expect(nextClose(client)).resolves.toMatchObject({
      code: REALTIME_CLOSE.dependencyUnavailable,
      reason: 'temporarily-unavailable',
    });
  });

  it('cleans up a disconnect so the same principal can reconnect and requires snapshot recovery', async () => {
    const first = await authenticatedClient();
    first.close();
    await nextClose(first);

    const second = await authenticatedClient();
    second.send(
      JSON.stringify({
        type: 'subscribe',
        requestId: 'resume',
        channel: 'account',
        resourceId: USER_ID,
        afterSequence: 4,
      }),
    );
    await expect(nextFrame(second)).resolves.toMatchObject({
      type: 'subscribed',
      recovery: 'snapshot-required',
    });
  });

  it('enforces the per-principal connection limit', async () => {
    const accepted: WebSocket[] = [];
    for (
      let index = 0;
      index < REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL;
      index += 1
    ) {
      accepted.push(await authenticatedClient());
    }
    const excess = await connect();
    excess.send(
      JSON.stringify({
        type: 'authenticate',
        accessToken: 'valid-access-token',
      }),
    );
    await expect(nextClose(excess)).resolves.toMatchObject({
      code: REALTIME_CLOSE.limitExceeded,
      reason: 'connection-limit',
    });
    expect(
      accepted.every((client) => client.readyState === WebSocket.OPEN),
    ).toBe(true);
  });

  it('enforces the per-connection subscription limit without dropping valid subscriptions', async () => {
    const client = await authenticatedClient();
    for (let index = 0; index < 10; index += 1) {
      client.send(
        JSON.stringify({
          type: 'subscribe',
          requestId: `subscription-${index}`,
          channel: 'account',
          resourceId: USER_ID,
        }),
      );
      await expect(nextFrame(client)).resolves.toMatchObject({
        type: 'subscribed',
        requestId: `subscription-${index}`,
      });
    }
    client.send(
      JSON.stringify({
        type: 'subscribe',
        requestId: 'subscription-excess',
        channel: 'account',
        resourceId: USER_ID,
      }),
    );
    await expect(nextFrame(client)).resolves.toEqual({
      type: 'subscription-denied',
      requestId: 'subscription-excess',
      code: 'limit-exceeded',
    });
    expect(client.readyState).toBe(WebSocket.OPEN);
  });

  it('rejects browser origins outside the configured allowlist', async () => {
    const client = new WebSocket(url, { origin: 'https://evil.example' });
    clients.add(client);
    await new Promise<void>((resolve, reject) => {
      client.once('open', resolve);
      client.once('error', reject);
    });
    await expect(nextClose(client)).resolves.toMatchObject({
      code: REALTIME_CLOSE.accessDenied,
      reason: 'origin-not-allowed',
    });
  });

  async function connect(): Promise<WebSocket> {
    const client = new WebSocket(url, { origin: 'https://app.fixnow.test' });
    clients.add(client);
    await new Promise<void>((resolve, reject) => {
      client.once('open', resolve);
      client.once('error', reject);
    });
    return client;
  }

  async function authenticatedClient(): Promise<WebSocket> {
    const client = await connect();
    client.send(
      JSON.stringify({
        type: 'authenticate',
        accessToken: 'valid-access-token',
      }),
    );
    await nextFrame(client);
    return client;
  }
});

function nextFrame(client: WebSocket): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    const onError = (error: Error) => {
      client.off('message', onMessage);
      reject(error);
    };
    const onMessage = (data: import('ws').RawData) => {
      client.off('error', onError);
      try {
        resolve(JSON.parse(rawDataText(data)) as Record<string, unknown>);
      } catch (error) {
        reject(error instanceof Error ? error : new Error('Invalid frame'));
      }
    };
    client.once('message', onMessage);
    client.once('error', onError);
  });
}

function nextClose(
  client: WebSocket,
): Promise<{ code: number; reason: string }> {
  return new Promise((resolve) => {
    client.once('close', (code, reason) =>
      resolve({ code, reason: reason.toString() }),
    );
  });
}

function rawDataText(data: import('ws').RawData): string {
  if (data instanceof ArrayBuffer) return Buffer.from(data).toString('utf8');
  if (Array.isArray(data)) return Buffer.concat(data).toString('utf8');
  return data.toString('utf8');
}
