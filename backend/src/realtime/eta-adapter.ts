import { Injectable } from '@nestjs/common';

export interface EtaInput {
  providerLatitude: number;
  providerLongitude: number;
  destinationLatitude: number;
  destinationLongitude: number;
}

export interface EtaEstimate {
  estimatedMinutes: number;
  source: string;
}

export abstract class EtaAdapter {
  abstract estimate(input: EtaInput): Promise<EtaEstimate | null>;
}

@Injectable()
export class BoundedFallbackEtaAdapter implements EtaAdapter {
  estimate(input: EtaInput): Promise<EtaEstimate | null> {
    const distanceKm = this.haversine(input);
    if (!Number.isFinite(distanceKm) || distanceKm > 200)
      return Promise.resolve(null);
    const minutes = Math.ceil((distanceKm / 25) * 60);
    return Promise.resolve({
      estimatedMinutes: Math.min(Math.max(minutes, 1), 480),
      source: 'bounded-distance-fallback',
    });
  }

  private haversine(input: EtaInput): number {
    const radians = (degrees: number) => (degrees * Math.PI) / 180;
    const lat1 = radians(input.providerLatitude);
    const lat2 = radians(input.destinationLatitude);
    const deltaLat = lat2 - lat1;
    const deltaLng = radians(
      input.destinationLongitude - input.providerLongitude,
    );
    const a =
      Math.sin(deltaLat / 2) ** 2 +
      Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLng / 2) ** 2;
    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
