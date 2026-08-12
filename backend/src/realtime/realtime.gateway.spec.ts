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
});
