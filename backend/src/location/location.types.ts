export interface ProviderPresenceUpdate {
  readonly online: boolean;
}

export interface LocationConsentUpdate {
  readonly bookingId: string;
  readonly granted: boolean;
  readonly noticeVersion: string;
}

export interface ProviderLocationUpdate {
  readonly bookingId: string;
  readonly sequence: number;
  readonly capturedAt: string;
  readonly latitude: number;
  readonly longitude: number;
  readonly accuracyMeters: number;
}

export interface CachedProviderLocation {
  readonly providerId: string;
  readonly bookingId: string;
  readonly sequence: number;
  readonly capturedAt: string;
  readonly receivedAt: string;
  readonly latitude: number;
  readonly longitude: number;
  readonly accuracyMeters: number;
}
