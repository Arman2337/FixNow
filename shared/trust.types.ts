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

export interface ProviderQualityMetricsContract {
  completedBookingCount: number;
  cancelledBookingCount: number;
  completionRate: number | null;
  averageRating: number | null;
  reviewCount: number;
  complaintCount: number;
}
