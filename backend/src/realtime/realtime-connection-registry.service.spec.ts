import { REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL } from './realtime.constants';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import type { RealtimeSubscription } from './realtime.types';
import type WebSocket from 'ws';

function socket(): WebSocket {
  return {} as WebSocket;
}

const subscription = (
  id: string,
  channel: 'account' | 'booking',
  resourceId: string,
): [string, RealtimeSubscription] => [id, { id, channel, resourceId }];

const principal = (userId: string, sessionId = 'session-1') =>
  ({ userId, sessionId, roles: ['customer'] }) as never;

describe('RealtimeConnectionRegistry re-authentication (BUG-013)', () => {
  let registry: RealtimeConnectionRegistry;
  let client: WebSocket;

  beforeEach(() => {
    registry = new RealtimeConnectionRegistry();
    client = socket();
    registry.registerPending(client, '127.0.0.1');
  });

  it('drops subscriptions when a socket re-authenticates as a different user', () => {
    expect(registry.authenticate(client, principal('user-a'), 'token-a')).toBe(
      true,
    );
    const state = registry.get(client)!;
    state.subscriptions.set(...subscription('sub-1', 'booking', 'booking-a'));
    state.subscriptions.set(...subscription('sub-2', 'account', 'user-a'));
    expect(state.subscriptions.size).toBe(2);

    // The socket now presents a different identity.
    expect(registry.authenticate(client, principal('user-b'), 'token-b')).toBe(
      true,
    );

    // The grants made for user-a must not survive.
    expect(registry.get(client)!.subscriptions.size).toBe(0);
    expect(registry.get(client)!.principal!.userId).toBe('user-b');
  });

  it('keeps subscriptions when the same user refreshes their token', () => {
    registry.authenticate(client, principal('user-a'), 'token-a');
    const state = registry.get(client)!;
    state.subscriptions.set(...subscription('sub-1', 'booking', 'booking-a'));

    // Same user, brand new session: a normal re-login.
    expect(
      registry.authenticate(
        client,
        principal('user-a', 'session-2'),
        'token-2',
      ),
    ).toBe(true);

    expect(registry.get(client)!.subscriptions.size).toBe(1);
  });

  it('does not let a re-authentication reset the rate-limit windows', () => {
    registry.authenticate(client, principal('user-a'), 'token-a');
    const state = registry.get(client)!;
    state.messageWindowStartedAt = 1_000;
    state.messageCount = 7;
    state.voiceWindowStartedAt = 2_000;
    state.voiceMessageCount = 3;

    // Even switching identity must not hand the client a fresh allowance.
    registry.authenticate(client, principal('user-b'), 'token-b');

    const after = registry.get(client)!;
    expect(after.messageWindowStartedAt).toBe(1_000);
    expect(after.messageCount).toBe(7);
    expect(after.voiceWindowStartedAt).toBe(2_000);
    expect(after.voiceMessageCount).toBe(3);
  });

  it('leaves state untouched when a re-authentication is refused', () => {
    // Fill the per-principal allowance, so the next attempt is rejected.
    expect(registry.authenticate(client, principal('user-a'), 'token-a')).toBe(
      true,
    );
    const sockets: WebSocket[] = [client];
    for (let i = 1; i < REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL; i += 1) {
      const extra = socket();
      registry.registerPending(extra, `127.0.0.${i + 1}`);
      expect(
        registry.authenticate(extra, principal('user-a', `session-${i}`), 't'),
      ).toBe(true);
      sockets.push(extra);
    }
    for (const [index, established] of sockets.entries()) {
      registry
        .get(established)!
        .subscriptions.set(
          ...subscription(`sub-${index}`, 'account', 'user-a'),
        );
    }

    // One over the limit: refused, and the rejection must be all-or-nothing.
    const overLimit = socket();
    registry.registerPending(overLimit, '127.0.0.9');
    expect(
      registry.authenticate(overLimit, principal('user-a'), 'token-extra'),
    ).toBe(false);

    for (const established of sockets) {
      expect(registry.get(established)!.subscriptions.size).toBe(1);
      expect(registry.get(established)!.principal!.userId).toBe('user-a');
    }
  });
});
