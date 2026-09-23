export type TrackingAvailability = 'live' | 'stale' | 'unavailable';

import type { BookingItemContract } from './booking-lifecycle.types';

export interface BookingTrackingProjection {
  bookingId: string;
  status: string;
  sequence: number;
  occurredAt: string;
  /**
   * Line items present on the booking, included so itemized changes
   * (e.g. a provider's on-site adjustment) reach subscribers without a
   * refetch. Absent for bookings without line items.
   */
  items?: BookingItemContract[];
  estimatedDurationMinutes?: number | null;
  location: {
    latitude: number;
    longitude: number;
    accuracyMeters: number;
    capturedAt: string;
    receivedAt: string;
  } | null;
  locationAvailability: TrackingAvailability;
  eta: {
    estimatedMinutes: number;
    calculatedAt: string;
    source: string;
  } | null;
  route: {
    distanceMeters: number;
    durationSeconds: number;
    coordinates: Array<[longitude: number, latitude: number]>;
  } | null;
}
