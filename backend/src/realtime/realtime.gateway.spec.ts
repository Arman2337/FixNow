import { ConfigService } from '@nestjs/config';
import type { IncomingMessage } from 'node:http';
import type { DataSource } from 'typeorm';
import { WebSocket } from 'ws';
import { AuthorizationService } from '../common/authorization/authorization.service';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeTelemetryService } from './realtime-telemetry.service';
import { LocationService } from '../location/location.service';
import { BookingProjectionService } from './booking-projection.service';

/**
 * The gateway's constructor grew dependencies over time. Building it through
 * one factory keeps these specs compiling when it changes again, and keeps each
 * test focused on the collaborator it actually cares about.
 */
function makeGateway(options?: {
  registry?: RealtimeConnectionRegistry;
  telemetry?: RealtimeTelemetryService;
  config?: ConfigService;
  dataSource?: DataSource;
  projections?: BookingProjectionService;
}): RealtimeGateway {
  return new RealtimeGateway(
    {} as AuthorizationService,
    options?.registry ?? new RealtimeConnectionRegistry(),
    options?.telemetry ?? new RealtimeTelemetryService(),
    options?.config ?? ({ get: jest.fn() } as unknown as ConfigService),
    {} as LocationService,
    options?.dataSource ?? ({} as DataSource),
    options?.projections ?? ({} as BookingProjectionService),
  );
}

/** Minimal DataSource stub: the voice-frame path only reads a call row. */
function voiceFrameDataSource() {
  return {
    getRepository: jest.fn().mockReturnValue({
      findOneBy: jest.fn().mockResolvedValue({
        id: 'call-xyz',
        bookingId: 'booking-123',
        callerUserId: 'user-1',
        calleeUserId: 'user-2',
        status: 'CONNECTED',
      }),
    }),
  };
}

/**
 * AuthorizationPrincipal is { userId, sessionId, roles }. Earlier versions of
 * these specs also passed scopes/type/permissions, which no longer exist on
 * the type, so they are built here instead of inline at each call site.
 */
function principal(
  userId: string,
  role: 'customer' | 'verified_provider',
  sessionId: string,
) {
  return { userId, sessionId, roles: [role] };
}

describe('RealtimeGateway heartbeat', () => {
  it('pings a healthy connection and terminates it when the next heartbeat is missed', () => {
    const registry = new RealtimeConnectionRegistry();
    const telemetry = new RealtimeTelemetryService();
    const ping = jest.fn();
    const terminate = jest.fn();
    const client = {
      readyState: WebSocket.OPEN,
      ping,
      terminate,
    } as unknown as WebSocket;
    registry.registerPending(client, '127.0.0.1');
    const gateway = makeGateway({ registry, telemetry });

    gateway.checkHeartbeats();
    expect(ping).toHaveBeenCalledTimes(1);
    expect(terminate).not.toHaveBeenCalled();

    gateway.checkHeartbeats();
    expect(terminate).toHaveBeenCalledTimes(1);
    expect(telemetry.snapshot()['heartbeat.timeout']).toBe(1);
    expect(registry.get(client)).toBeUndefined();
  });

  it('relays call.voice-frame.v1 between clients subscribed to the same booking', async () => {
    const registry = new RealtimeConnectionRegistry();
    const telemetry = new RealtimeTelemetryService();
    const gateway = makeGateway({
      registry,
      telemetry,
      dataSource: voiceFrameDataSource() as unknown as DataSource,
    });

    const client1Send = jest.fn();
    const client2Send = jest.fn<void, [data: string]>();
    const client1 = {
      readyState: WebSocket.OPEN,
      send: client1Send,
      close: jest.fn(),
    } as unknown as WebSocket;
    const client2 = {
      readyState: WebSocket.OPEN,
      send: client2Send,
      close: jest.fn(),
    } as unknown as WebSocket;

    registry.registerPending(client1, '127.0.0.1');
    registry.registerPending(client2, '127.0.0.1');
    registry.authenticate(
      client1,
      principal('user-1', 'customer', 'session-1'),
      'token-1',
    );
    registry.authenticate(
      client2,
      principal('user-2', 'verified_provider', 'session-2'),
      'token-2',
    );

    // Both subscribe to booking-123
    const state1 = registry.get(client1)!;
    const state2 = registry.get(client2)!;
    state1.subscriptions.set('sub-1', {
      id: 'sub-1',
      channel: 'booking',
      resourceId: 'booking-123',
    });
    state2.subscriptions.set('sub-2', {
      id: 'sub-2',
      channel: 'booking',
      resourceId: 'booking-123',
    });

    const voiceMessage = JSON.stringify({
      type: 'call.voice-frame.v1',
      bookingId: 'booking-123',
      callId: 'call-xyz',
      data: 'AQIDBAU=',
    });

    // Client 1 sends a voice frame
    await gateway.onMessage(client1, Buffer.from(voiceMessage), false);

    // Client 1 should NOT receive its own frame
    expect(client1Send).not.toHaveBeenCalled();

    // Client 2 SHOULD receive the relayed voice frame
    expect(client2Send).toHaveBeenCalledTimes(1);
    const rawReceived: unknown = client2Send.mock.calls[0]?.[0];
    expect(typeof rawReceived).toBe('string');
    if (typeof rawReceived !== 'string') throw new Error('Missing voice frame');
    const received: unknown = JSON.parse(rawReceived);
    expect(received).toEqual({
      type: 'call.voice-frame.v1',
      bookingId: 'booking-123',
      callId: 'call-xyz',
      data: 'AQIDBAU=',
    });
  });

  it('rejects voice frames from users who are not call participants', async () => {
    const registry = new RealtimeConnectionRegistry();
    const telemetry = new RealtimeTelemetryService();
    const gateway = makeGateway({
      registry,
      telemetry,
      dataSource: voiceFrameDataSource() as unknown as DataSource,
    });
    const client1Send = jest.fn();
    const client2Send = jest.fn<void, [data: string]>();
    const client1 = {
      readyState: WebSocket.OPEN,
      send: client1Send,
    } as unknown as WebSocket;
    const client2 = {
      readyState: WebSocket.OPEN,
      send: client2Send,
    } as unknown as WebSocket;
    registry.registerPending(client1, '127.0.0.1');
    registry.registerPending(client2, '127.0.0.1');
    registry.authenticate(
      client1,
      principal('user-3', 'customer', 'session-3'),
      'token-3',
    );
    registry.authenticate(
      client2,
      principal('user-2', 'verified_provider', 'session-2'),
      'token-2',
    );
    for (const [client, id] of [
      [client1, 'sub-1'],
      [client2, 'sub-2'],
    ] as const) {
      registry.get(client)!.subscriptions.set(id, {
        id,
        channel: 'booking',
        resourceId: 'booking-123',
      });
    }

    await gateway.onMessage(
      client1,
      Buffer.from(
        JSON.stringify({
          type: 'call.voice-frame.v1',
          bookingId: 'booking-123',
          callId: 'call-xyz',
          data: 'AQIDBAU=',
        }),
      ),
      false,
    );

    expect(client1Send).not.toHaveBeenCalled();
    expect(client2Send).not.toHaveBeenCalled();
  });

  it('accepts localhost browser origins during development', () => {
    const registry = new RealtimeConnectionRegistry();
    const telemetry = new RealtimeTelemetryService();
    const gateway = makeGateway({
      registry,
      telemetry,
      config: {
        get: jest.fn((key: string) =>
          key === 'NODE_ENV' ? 'development' : undefined,
        ),
      } as unknown as ConfigService,
    });
    const close = jest.fn();
    const client = {
      readyState: WebSocket.OPEN,
      on: jest.fn(),
      close,
    } as unknown as WebSocket;
    const request = {
      headers: { origin: 'http://localhost:54321' },
      socket: { remoteAddress: '127.0.0.1' },
    } as unknown as IncomingMessage;

    gateway.handleConnection(client, request);

    expect(close).not.toHaveBeenCalled();
  });

  it('closes browser origins that are not allowlisted outside development', () => {
    const registry = new RealtimeConnectionRegistry();
    const telemetry = new RealtimeTelemetryService();
    const gateway = makeGateway({
      registry,
      telemetry,
      config: {
        get: jest.fn((key: string) =>
          key === 'NODE_ENV' ? 'production' : undefined,
        ),
      } as unknown as ConfigService,
    });
    const close = jest.fn();
    const client = {
      readyState: WebSocket.OPEN,
      on: jest.fn(),
      close,
    } as unknown as WebSocket;
    const request = {
      headers: { origin: 'https://evil.example.com' },
      socket: { remoteAddress: '203.0.113.9' },
    } as unknown as IncomingMessage;

    gateway.handleConnection(client, request);

    expect(close).toHaveBeenCalledWith(expect.anything(), 'origin-not-allowed');
  });
});
