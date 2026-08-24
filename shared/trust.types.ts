export enum TrustSignalSeverity {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
}

export enum TrustSignalStatus {
  OPEN = 'OPEN',
  REVIEWED = 'REVIEWED',
  DISMISSED = 'DISMISSED',
}

export enum AppealStatus {
  NONE = 'NONE',
  PENDING = 'PENDING',
  GRANTED = 'GRANTED',
  DENIED = 'DENIED',
}

export interface ProviderQualityMetricsContract {
  completedBookingCount: number;
  cancelledBookingCount: number;
  completionRate: number | null;
  averageRating: number | null;
  reviewCount: number;
  complaintCount: number;
}

export interface ProviderAcceptTimeContract {
  /** Rolling mean of request→accept latency in whole minutes; null hides the signal entirely. */
  averageAcceptMinutes: number | null;
  sampleSize: number;
  windowDays: number;
}
