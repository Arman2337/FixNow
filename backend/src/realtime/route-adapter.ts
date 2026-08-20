import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EtaInput } from './eta-adapter';

export interface DrivingRoute {
  distanceMeters: number;
  durationSeconds: number;
  coordinates: Array<[longitude: number, latitude: number]>;
}

export abstract class RouteAdapter {
  abstract route(input: EtaInput): Promise<DrivingRoute | null>;
}

@Injectable()
export class OpenRouteServiceAdapter implements RouteAdapter {
  constructor(private readonly config: ConfigService) {}

  async route(input: EtaInput): Promise<DrivingRoute | null> {
    const key = this.config.get<string>('OPENROUTESERVICE_API_KEY')?.trim();
    if (!key) return null;
    try {
      const response = await fetch(
        'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
        {
          method: 'POST',
          headers: {
            Authorization: key,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            coordinates: [
              [input.providerLongitude, input.providerLatitude],
              [input.destinationLongitude, input.destinationLatitude],
            ],
          }),
          signal: AbortSignal.timeout(5_000),
        },
      );
      if (!response.ok) return null;
      return parseOpenRouteServiceRoute(await response.json());
    } catch {
      // A route must never block the live-location projection. The bounded ETA
      // remains available when the optional external service is unavailable.
      return null;
    }
  }
}

export function parseOpenRouteServiceRoute(value: unknown): DrivingRoute | null {
  if (!value || typeof value !== 'object') return null;
  const record = value as Record<string, unknown>;
  const features = record.features;
  if (!Array.isArray(features) || features.length === 0) return null;
  const feature = features[0];
  if (!feature || typeof feature !== 'object') return null;
  const featureRecord = feature as Record<string, unknown>;
  const properties = featureRecord.properties;
  const geometry = featureRecord.geometry;
  if (!properties || typeof properties !== 'object' || !geometry || typeof geometry !== 'object') return null;
  const summary = (properties as Record<string, unknown>).summary;
  const rawCoordinates = (geometry as Record<string, unknown>).coordinates;
  if (!summary || typeof summary !== 'object' || !Array.isArray(rawCoordinates)) return null;
  const distance = (summary as Record<string, unknown>).distance;
  const duration = (summary as Record<string, unknown>).duration;
  if (typeof distance !== 'number' || typeof duration !== 'number' || distance <= 0 || duration <= 0) return null;
  const coordinates = rawCoordinates.flatMap((point): Array<[number, number]> => {
    if (!Array.isArray(point) || point.length < 2 || typeof point[0] !== 'number' || typeof point[1] !== 'number') return [];
    return [[point[0], point[1]]];
  });
  if (coordinates.length < 2) return null;
  return {
    distanceMeters: distance,
    durationSeconds: duration,
    coordinates: sampleCoordinates(coordinates),
  };
}

function sampleCoordinates(
  coordinates: Array<[number, number]>,
): Array<[number, number]> {
  const maximumPoints = 80;
  if (coordinates.length <= maximumPoints) return coordinates;
  const step = (coordinates.length - 1) / (maximumPoints - 1);
  return Array.from({ length: maximumPoints }, (_, index) =>
    coordinates[Math.round(index * step)],
  );
}
