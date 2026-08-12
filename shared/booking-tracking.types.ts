export type TrackingAvailability = 'live' | 'stale' | 'unavailable';

export interface BookingTrackingProjection {
  bookingId: string;
  status: string;
  sequence: number;
  occurredAt: string;
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
}
