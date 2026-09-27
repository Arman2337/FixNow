import { Injectable } from '@nestjs/common';
import type WebSocket from 'ws';
import {
  REALTIME_MAX_CONNECTIONS_PER_PRINCIPAL,
  REALTIME_MAX_PENDING_CONNECTIONS_PER_ADDRESS,
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
    return true;
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
