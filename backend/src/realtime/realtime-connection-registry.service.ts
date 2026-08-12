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
