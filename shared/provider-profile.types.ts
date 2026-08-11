export interface ProviderProfile {
  id: string;
  userId: string;
  displayName: string;
  bio: string | null;
  serviceRadiusKm: number;
  baseLatitude: number;
  baseLongitude: number;
  skillIds: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface UpsertProviderProfileRequest {
  displayName: string;
  bio?: string | null;
  serviceRadiusKm: number;
  baseLatitude: number;
  baseLongitude: number;
}

export interface CoverageCheckRequest {
  latitude: number;
  longitude: number;
}

export interface CoverageCheckResponse {
  isWithinServiceArea: boolean;
}
