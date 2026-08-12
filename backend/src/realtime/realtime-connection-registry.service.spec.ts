import type WebSocket from 'ws';
import {
  REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL,
  REALTIME_MAX_PENDING_CONNECTIONS_PER_ADDRESS,
} from './realtime.constants';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';

describe('RealtimeConnectionRegistry', () => {
  const principal = {
    userId: 'user-1',
    sessionId: 'session-1',
    roles: ['customer'] as const,
  };

  it('bounds unauthenticated connections by network address', () => {
    const registry = new RealtimeConnectionRegistry();
    for (
      let index = 0;
      index < REALTIME_MAX_PENDING_CONNECTIONS_PER_ADDRESS;
      index += 1
    ) {
      expect(registry.registerPending(socket(), '127.0.0.1')).toBe(true);
    }
    expect(registry.registerPending(socket(), '127.0.0.1')).toBe(false);
  });

  it('bounds authenticated connections and releases quota on disconnect', () => {
    const registry = new RealtimeConnectionRegistry();
    const active: WebSocket[] = [];
    for (
      let index = 0;
      index < REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL;
      index += 1
    ) {
      const client = socket();
      active.push(client);
      registry.registerPending(client, `address-${index}`);
      expect(registry.authenticate(client, principal, 'token')).toBe(true);
    }
    const excess = socket();
    registry.registerPending(excess, 'other-address');
    expect(registry.authenticate(excess, principal, 'token')).toBe(false);
    registry.remove(active[0]);
    expect(registry.authenticate(excess, principal, 'token')).toBe(true);
  });
});

function socket(): WebSocket {
  return {} as WebSocket;
}
