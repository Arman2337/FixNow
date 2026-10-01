import {
  ForbiddenException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { DataSource } from 'typeorm';
import { WebSocket } from 'ws';
import { AuthorizationService } from '../common/authorization/authorization.service';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeTelemetryService } from './realtime-telemetry.service';
import { REALTIME_SESSION_REVALIDATION_MS } from './realtime.constants';
import { LocationService } from '../location/location.service';
import { BookingProjectionService } from './booking-projection.service';

const principal = (userId: string) => ({
  userId,
  sessionId: 'session-1',
  roles: ['customer'],
});

/**
 * BUG-026. The realtime access token was verified once, at `authenticate`.
 *
 * `auth_sessions` also carries `expires_at` and `revoked_at`, and neither was
 * ever re-read, so a revoked session - or a suspended user - kept an open socket
 * receiving booking state, chat and voice signalling for the life of the
 * process. On a provider's always-on socket that is days.
 *
 * Every HTTP request in this system re-reads the user row and the full role set
 * per request, precisely so that a revocation takes effect immediately. The
 * realtime channel carried the same data and skipped that, which made it the
 * one place a revocation did not apply.
 *
 * The two behaviours below are the ones that matter and that are easy to get
 * backwards:
 *
 *   1. A definite denial closes the socket.
 *   2. An inconclusive check - a database blip - closes nothing, because
 *      treating a timeout as a revocation disconnects every provider on the
 *      platform during a momentary outage.
 */
describe('RealtimeGateway session revalidation (BUG-026)', () => {
  let registry: RealtimeConnectionRegistry;
  let telemetry: RealtimeTelemetryService;
  let authorizeAccessToken: jest.Mock;
  let sockets: WebSocket[];

  const build = (): RealtimeGateway => {
    sockets = [];
    registry = new RealtimeConnectionRegistry();
    telemetry = new RealtimeTelemetryService();
    const authorization = {
      authorizeAccessToken,
    } as unknown as AuthorizationService;
    return new RealtimeGateway(
      authorization,
      registry,
      telemetry,
      { get: jest.fn() } as unknown as ConfigService,
      {} as LocationService,
      {} as DataSource,
      {} as BookingProjectionService,
    );
  };

  /**
   * A fake socket, plus its close mock as a separate binding.
   *
   * The mock is returned alongside rather than read back off the socket: the
   * unbound-method rule is right that expect(socket.close) reads a method
   * off an object, and a jest mock returned from a factory is both clearer to
   * assert on and immune to that. The runtime behaviour under test - which
   * close code and reason a denial produces - is identical either way.
   */
  const makeSocket = (): { client: WebSocket; close: jest.Mock } => {
    const close = jest.fn();
    const client = {
      readyState: WebSocket.OPEN,
      close,
      terminate: jest.fn(),
      ping: jest.fn(),
      on: jest.fn(),
      send: jest.fn(),
    } as unknown as WebSocket;
    return { client, close };
  };

  /** Registers an authenticated socket. */
  const connect = async (
    gateway: RealtimeGateway,
    token = 'token-1',
  ): Promise<{ client: WebSocket; close: jest.Mock }> => {
    const socket = makeSocket();
    const { client } = socket;
    sockets.push(client);
    registry.registerPending(client, '127.0.0.1');
    await gateway.onMessage(
      client,
      Buffer.from(JSON.stringify({ type: 'authenticate', accessToken: token })),
      false,
    );
    return socket;
  };

  beforeEach(() => {
    authorizeAccessToken = jest.fn().mockResolvedValue(principal('user-1'));
  });

  it('does not re-check a connection inside the window', async () => {
    const gateway = build();
    await connect(gateway);
    authorizeAccessToken.mockClear();

    await gateway.revalidateSessions(Date.now());

    expect(authorizeAccessToken).not.toHaveBeenCalled();
  });

  it('re-checks once the window has passed', async () => {
    const gateway = build();
    const { close } = await connect(gateway);
    authorizeAccessToken.mockClear();

    const closed = await gateway.revalidateSessions(
      Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1,
    );

    expect(authorizeAccessToken).toHaveBeenCalledTimes(1);
    expect(closed).toBe(0);
    expect(close).not.toHaveBeenCalled();
  });

  it('closes a socket whose session was revoked', async () => {
    const gateway = build();
    const { close } = await connect(gateway);
    authorizeAccessToken.mockRejectedValue(new UnauthorizedException());

    const closed = await gateway.revalidateSessions(
      Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1,
    );

    expect(closed).toBe(1);
    expect(close).toHaveBeenCalledWith(4403, 'session-no-longer-valid');
    expect(telemetry.snapshot()['session.revoked']).toBe(1);
  });

  it('closes a socket belonging to a suspended account', async () => {
    const gateway = build();
    const { close } = await connect(gateway);
    // A suspended user is a Forbidden, not an Unauthorized - the token is fine,
    // the account is not usable. Both are denials and both must close the socket.
    authorizeAccessToken.mockRejectedValue(new ForbiddenException());

    expect(
      await gateway.revalidateSessions(
        Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1,
      ),
    ).toBe(1);
    expect(close).toHaveBeenCalled();
  });

  // The dangerous mistake. A database blip is not a revocation, and treating it
  // as one disconnects every provider on the platform during a momentary outage.
  it('closes nothing when the check could not reach a conclusion', async () => {
    const gateway = build();
    const { close } = await connect(gateway);
    authorizeAccessToken.mockRejectedValue(
      new ServiceUnavailableException('database is down'),
    );

    const closed = await gateway.revalidateSessions(
      Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1,
    );

    expect(closed).toBe(0);
    expect(close).not.toHaveBeenCalled();
    expect(telemetry.snapshot()['session.revalidation.deferred']).toBe(1);
  });

  // A token that now resolves to a different user is a substitution, not a
  // refresh, and the subscriptions on this socket were granted to the previous
  // identity - which is BUG-013 resurfacing through a different door.
  it('closes a socket whose token now identifies someone else', async () => {
    const gateway = build();
    const { close } = await connect(gateway);
    authorizeAccessToken.mockResolvedValue(principal('user-2'));

    expect(
      await gateway.revalidateSessions(
        Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1,
      ),
    ).toBe(1);
    expect(close).toHaveBeenCalledWith(4403, 'session-no-longer-valid');
  });

  it('retries after a deferral rather than waiting another full window', async () => {
    const gateway = build();
    await connect(gateway);
    authorizeAccessToken.mockRejectedValue(
      new ServiceUnavailableException('database is down'),
    );
    const at = Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1;
    await gateway.revalidateSessions(at);
    authorizeAccessToken.mockClear();

    // The window was not reset by the failed check, so the very next heartbeat
    // tries again. Waiting a full minute again would leave a revoked session
    // live for another minute after the database came back.
    await gateway.revalidateSessions(at + 1);
    expect(authorizeAccessToken).toHaveBeenCalled();
  });

  it('resets the window after a successful check', async () => {
    const gateway = build();
    await connect(gateway);
    const at = Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1;
    await gateway.revalidateSessions(at);
    authorizeAccessToken.mockClear();

    await gateway.revalidateSessions(at + 1);
    expect(authorizeAccessToken).not.toHaveBeenCalled();
  });

  it('ignores connections that never authenticated', async () => {
    const gateway = build();
    const { client } = makeSocket();
    registry.registerPending(client, '127.0.0.1');

    await gateway.revalidateSessions(
      Date.now() + REALTIME_SESSION_REVALIDATION_MS + 1,
    );
    expect(authorizeAccessToken).not.toHaveBeenCalled();
  });
});
