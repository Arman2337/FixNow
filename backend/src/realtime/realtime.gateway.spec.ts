import { ConfigService } from '@nestjs/config';
import { WebSocket } from 'ws';
import { AuthorizationService } from '../common/authorization/authorization.service';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeTelemetryService } from './realtime-telemetry.service';
import { LocationService } from '../location/location.service';

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
    const gateway = new RealtimeGateway(
      {} as AuthorizationService,
      registry,
      telemetry,
      { get: jest.fn() } as unknown as ConfigService,
      {} as LocationService,
    );

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
    const gateway = new RealtimeGateway(
      {} as AuthorizationService,
      registry,
      telemetry,
      { get: jest.fn() } as unknown as ConfigService,
      {} as LocationService,
    );

    const client1Send = jest.fn();
    const client2Send = jest.fn();
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
      {
        userId: 'user-1',
        roles: ['CUSTOMER'],
        scopes: [],
        type: 'CUSTOMER',
        permissions: [],
      },
      'token-1',
    );
    registry.authenticate(
      client2,
      {
        userId: 'user-2',
        roles: ['PROVIDER'],
        scopes: [],
        type: 'PROVIDER',
        permissions: [],
      },
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
    const received = JSON.parse(client2Send.mock.calls[0][0]);
    expect(received).toEqual({
      type: 'call.voice-frame.v1',
      bookingId: 'booking-123',
      callId: 'call-xyz',
      data: 'AQIDBAU=',
    });
  });
});
