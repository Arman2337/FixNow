import { Injectable } from '@nestjs/common';
import type WebSocket from 'ws';
import {
  REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL,
  REALTIME_MAX_PENDING_CONNECTIONS_PER_ADDRESS,
  REALTIME_SESSION_REVALIDATION_MS,
} from './realtime.constants';
import type { RealtimeConnectionState } from './realtime.types';

@Injectable()
export class RealtimeConnectionRegistry {
  private readonly states = new Map<WebSocket, RealtimeConnectionState>();

  registerPending(
    client: WebSocket,
    address: string,
    now = Date.now(),
  ): boolean {
    const pendingForAddress = [...this.states.values()].filter(
      (state) => !state.principal && state.address === address,
    ).length;
    if (pendingForAddress >= REALTIME_MAX_PENDING_CONNECTIONS_PER_ADDRESS)
      return false;
    this.states.set(client, {
      address,
      alive: true,
      messageWindowStartedAt: now,
      messageCount: 0,
      subscriptions: new Map(),
    });
    return true;
  }

  authenticate(
    client: WebSocket,
    principal: NonNullable<RealtimeConnectionState['principal']>,
    accessToken: string,
    now = Date.now(),
  ): boolean {
    const activeForPrincipal = [...this.states.entries()].filter(
      ([socket, state]) =>
        socket !== client && state.principal?.userId === principal.userId,
    ).length;
    if (activeForPrincipal >= REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL)
      return false;
    const state = this.states.get(client);
    if (!state) return false;

    // BUG-013. A socket may re-authenticate at any time, and the handler used
    // to overwrite the principal while keeping every subscription. Those
    // subscriptions were granted on the strength of the *previous* principal, so
    // a socket that re-authenticated as a different account kept receiving the
    // first account's booking and account frames.
    //
    // Subscriptions are therefore dropped whenever the identity actually
    // changes. The common cases - a token refresh, or signing in again on the
    // same socket - keep their subscriptions, because a subscription is granted
    // to a *user*, not to a session, so a new sessionId for the same userId is
    // not an identity change.
    //
    // The rate-limit windows are deliberately NOT reset: they are per socket,
    // not per principal, and clearing them here would let a client reset its
    // own limit by re-authenticating.
    const identityChanged =
      state.principal !== undefined &&
      state.principal.userId !== principal.userId;
    if (identityChanged) {
      state.subscriptions.clear();
    }

    state.principal = principal;
    state.accessToken = accessToken;
    state.authenticatedAt = now;
    // BUG-026. A fresh authentication is also a fresh session check, so the
    // revalidation window restarts here rather than inheriting whatever the
    // previous principal left behind.
    state.sessionVerifiedAt = now;
    return true;
  }

  /**
   * BUG-026. Connections whose session has not been confirmed within the
   * revalidation window.
   *
   * The token was verified once, at `authenticate`. `auth_sessions.expires_at`
   * and `revoked_at` were never re-read, so a revoked session kept receiving
   * frames for the life of the process - on a provider's always-on socket, days.
   * Every HTTP request re-reads the session per request; this restores the same
   * property to the channel that carries the same data.
   *
   * Bounded so a burst of connections cannot turn into a burst of database
   * queries: the cheapest correct answer is "is it time to look again", and a
   * socket that reconnects every few seconds is not worth a query per heartbeat.
   */
  dueForSessionRevalidation(
    now = Date.now(),
    windowMs = REALTIME_SESSION_REVALIDATION_MS,
  ): Array<{ client: WebSocket; state: RealtimeConnectionState }> {
    const due: Array<{
      client: WebSocket;
      state: RealtimeConnectionState;
    }> = [];
    for (const [client, state] of this.states) {
      if (!state.principal) continue;
      if (now - (state.sessionVerifiedAt ?? 0) < windowMs) continue;
      due.push({ client, state });
    }
    return due;
  }

  /**
   * Records a successful re-check.
   *
   * Only a stamp, deliberately. Removal is the caller's decision, because the
   * caller is the only thing that knows *why* the check passed - a socket whose
   * identity changed is not the same event as one whose session was revoked, and
   * both need a different close reason for the client.
   */
  markSessionVerified(client: WebSocket, now = Date.now()): void {
    const state = this.states.get(client);
    if (state) state.sessionVerifiedAt = now;
  }

  get(client: WebSocket): RealtimeConnectionState | undefined {
    return this.states.get(client);
  }

  remove(client: WebSocket): void {
    const state = this.states.get(client);
    if (state?.authTimer) clearTimeout(state.authTimer);
    if (state) state.accessToken = undefined;
    this.states.delete(client);
  }

  entries(): IterableIterator<[WebSocket, RealtimeConnectionState]> {
    return this.states.entries();
  }
}
