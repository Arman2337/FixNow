import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { WebSocket } from 'ws';
import type { BookingTrackingProjection } from '../../../shared/booking-tracking.types';
import type { Booking } from '../bookings/domain/booking.entity';
import type { CachedProviderLocation } from '../location/location.types';
import { RealtimeConnectionRegistry } from './realtime-connection-registry.service';
import { EtaAdapter } from './eta-adapter';
import { RouteAdapter } from './route-adapter';

@Injectable()
export class BookingProjectionService {
  constructor(
    private readonly registry: RealtimeConnectionRegistry,
    private readonly eta: EtaAdapter,
    private readonly routes: RouteAdapter,
  ) {}

  publishBooking(booking: Booking): Promise<void> {
    return this.publish(booking, null, 'unavailable');
  }

  publishLocation(
    booking: Booking,
    location: CachedProviderLocation,
  ): Promise<void> {
    return this.publish(booking, location, 'live');
  }

  publishUnavailable(booking: Booking): Promise<void> {
    return this.publish(booking, null, 'unavailable');
  }

  private async publish(
    booking: Booking,
    location: CachedProviderLocation | null,
    availability: BookingTrackingProjection['locationAvailability'],
  ): Promise<void> {
    const occurredAt = new Date().toISOString();
    const route = location
      ? await this.routes.route({
          providerLatitude: location.latitude,
          providerLongitude: location.longitude,
          destinationLatitude: Number(booking.locationLat),
          destinationLongitude: Number(booking.locationLng),
        })
      : null;
    const estimate = location
      ? route
        ? {
            estimatedMinutes: Math.max(
              1,
              Math.ceil(route.durationSeconds / 60),
            ),
            source: 'openrouteservice-driving',
          }
        : await this.eta.estimate({
            providerLatitude: location.latitude,
            providerLongitude: location.longitude,
            destinationLatitude: Number(booking.locationLat),
            destinationLongitude: Number(booking.locationLng),
          })
      : null;
    const data: BookingTrackingProjection = {
      bookingId: booking.id,
      status: booking.status,
      sequence: booking.version,
      occurredAt,
      location: location
        ? {
            latitude: location.latitude,
            longitude: location.longitude,
            accuracyMeters: location.accuracyMeters,
            capturedAt: location.capturedAt,
            receivedAt: location.receivedAt,
          }
        : null,
      locationAvailability: availability,
      eta: estimate ? { ...estimate, calculatedAt: occurredAt } : null,
      route,
    };
    for (const [client, state] of this.registry.entries()) {
      if (client.readyState !== WebSocket.OPEN) continue;
      for (const subscription of state.subscriptions.values()) {
        if (
          subscription.channel === 'booking' &&
          subscription.resourceId === booking.id
        ) {
          client.send(
            JSON.stringify({
              type: 'booking.projection-updated.v1',
              eventId: randomUUID(),
              subscriptionId: subscription.id,
              resourceId: booking.id,
              sequence: booking.version,
              occurredAt,
              data,
            }),
          );
        }
      }
    }
  }

  publishChatMessage(
    bookingId: string,
    message: Readonly<Record<string, unknown>>,
  ): void {
    const occurredAt = new Date().toISOString();
    for (const [client, state] of this.registry.entries()) {
      if (client.readyState !== WebSocket.OPEN) continue;
      for (const subscription of state.subscriptions.values()) {
        if (
          subscription.channel === 'booking' &&
          subscription.resourceId === bookingId
        ) {
          client.send(
            JSON.stringify({
              type: 'chat.message-received.v1',
              eventId: randomUUID(),
              subscriptionId: subscription.id,
              resourceId: bookingId,
              occurredAt,
              data: message,
            }),
          );
        }
      }
    }
  }

  isSubscriberActive(bookingId: string, userId: string): boolean {
    for (const [client, state] of this.registry.entries()) {
      if (client.readyState !== WebSocket.OPEN) continue;
      if (state.principal?.userId === userId) {
        for (const subscription of state.subscriptions.values()) {
          if (
            subscription.channel === 'booking' &&
            subscription.resourceId === bookingId
          ) {
            return true;
          }
        }
      }
    }
    return false;
  }

  publishCallSignal(
    bookingId: string,
    signalType: string,
    data: Readonly<Record<string, unknown>>,
  ): void {
    const occurredAt = new Date().toISOString();
    for (const [client, state] of this.registry.entries()) {
      if (client.readyState !== WebSocket.OPEN) continue;
      for (const subscription of state.subscriptions.values()) {
        if (
          subscription.channel === 'booking' &&
          subscription.resourceId === bookingId
        ) {
          client.send(
            JSON.stringify({
              type: signalType,
              eventId: randomUUID(),
              subscriptionId: subscription.id,
              resourceId: bookingId,
              occurredAt,
              data,
            }),
          );
        }
      }
    }
  }
}
