import { Injectable, Logger } from '@nestjs/common';
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

interface RouteCacheEntry {
  originLatitude: number;
  originLongitude: number;
  destinationLatitude: number;
  destinationLongitude: number;
  fetchedAtMs: number;
  route: DrivingRoute;
}

/**
 * The free OpenRouteService plan allows 200 requests per day. The provider app
 * publishes live GPS every 11 seconds, so an unrouted projection would spend the
 * whole daily budget in half an hour and then silently degrade to a straight
 * line for the rest of the day.
 *
 * A road route between two points 50 m apart is the same road route, so the
 * adapter reuses the last answer until the technician has actually moved or the
 * refresh window has elapsed.
 */
@Injectable()
export class OpenRouteServiceAdapter implements RouteAdapter {
  private readonly logger = new Logger(OpenRouteServiceAdapter.name);
  private readonly cache = new Map<string, RouteCacheEntry>();
  private readonly inFlight = new Map<string, Promise<DrivingRoute | null>>();

  constructor(private readonly config: ConfigService) {}

  private get refreshMinIntervalMs(): number {
    return this.positiveInt('ROUTE_REFRESH_MIN_INTERVAL_MS', 60_000);
  }

  private get refreshMinMeters(): number {
    return this.positiveNumber('ROUTE_REFRESH_MIN_METERS', 50);
  }

  private get maxCacheAgeMs(): number {
    return this.positiveInt('ROUTE_MAX_CACHE_AGE_MS', 600_000);
  }

  private positiveInt(key: string, fallback: number): number {
    const raw = this.config.get<string>(key);
    const parsed = raw ? Number.parseInt(raw, 10) : Number.NaN;
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
  }

  private positiveNumber(key: string, fallback: number): number {
    const raw = this.config.get<string>(key);
    const parsed = raw ? Number.parseFloat(raw) : Number.NaN;
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
  }

  async route(input: EtaInput): Promise<DrivingRoute | null> {
    const key = this.config.get<string>('OPENROUTESERVICE_API_KEY')?.trim();
    if (!key) return null;

    const destinationKey = `${input.destinationLatitude.toFixed(5)},${input.destinationLongitude.toFixed(5)}`;
    const cached = this.cache.get(destinationKey);
    const fresh = cached ? this.isUsable(cached, input) : false;
    if (cached && fresh) return cached.route;

    // Collapse the bursts that arrive while a request is already open.
    const pending = this.inFlight.get(destinationKey);
    if (pending) return pending;

    const request = this.fetchRoute(key, input)
      .then((route) => {
        if (route) {
          this.cache.set(destinationKey, {
            originLatitude: input.providerLatitude,
            originLongitude: input.providerLongitude,
            destinationLatitude: input.destinationLatitude,
            destinationLongitude: input.destinationLongitude,
            fetchedAtMs: Date.now(),
            route,
          });
          return route;
        }
        // A failed refresh must not blank a route the technician is following.
        return cached && this.isWithinMaxAge(cached) ? cached.route : null;
      })
      .finally(() => this.inFlight.delete(destinationKey));

    this.inFlight.set(destinationKey, request);
    return request;
  }

  private isUsable(entry: RouteCacheEntry, input: EtaInput): boolean {
    if (!this.isWithinMaxAge(entry)) return false;
    if (entry.destinationLatitude !== input.destinationLatitude) return false;
    if (entry.destinationLongitude !== input.destinationLongitude) return false;
    const movedMeters = haversineMeters(
      entry.originLatitude,
      entry.originLongitude,
      input.providerLatitude,
      input.providerLongitude,
    );
    if (movedMeters < this.refreshMinMeters) return true;
    return Date.now() - entry.fetchedAtMs >= this.refreshMinIntervalMs;
  }

  private isWithinMaxAge(entry: RouteCacheEntry): boolean {
    return Date.now() - entry.fetchedAtMs < this.maxCacheAgeMs;
  }

  private async fetchRoute(
    key: string,
    input: EtaInput,
  ): Promise<DrivingRoute | null> {
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
      if (!response.ok) {
        if (
          response.status === 429 ||
          response.status === 401 ||
          response.status === 403
        ) {
          this.logger.warn(
            `OpenRouteService rejected the request (${response.status}); the daily quota is 200 and the cached route is being reused until it expires.`,
          );
        }
        return null;
      }
      return parseOpenRouteServiceRoute(
        JSON.parse(await response.text()) as unknown,
      );
    } catch {
      // A route must never block the live-location projection. The bounded ETA
      // remains available when the optional external service is unavailable.
      return null;
    }
  }
}

/** Great-circle distance in meters. Exported for the refresh-threshold tests. */
export function haversineMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const toRadians = Math.PI / 180;
  const dLat = (lat2 - lat1) * toRadians;
  const dLon = (lon2 - lon1) * toRadians;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * toRadians) *
      Math.cos(lat2 * toRadians) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return 2 * 6371000 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function parseOpenRouteServiceRoute(
  value: unknown,
): DrivingRoute | null {
  if (!value || typeof value !== 'object') return null;
  const record = value as Record<string, unknown>;
  const features = record.features;
  if (!Array.isArray(features) || features.length === 0) return null;
  const feature: unknown = features[0] as unknown;
  if (!feature || typeof feature !== 'object') return null;
  const featureRecord = feature as Record<string, unknown>;
  const properties = featureRecord.properties;
  const geometry = featureRecord.geometry;
  if (
    !properties ||
    typeof properties !== 'object' ||
    !geometry ||
    typeof geometry !== 'object'
  )
    return null;
  const summary = (properties as Record<string, unknown>).summary;
  const rawCoordinates = (geometry as Record<string, unknown>).coordinates;
  if (!summary || typeof summary !== 'object' || !Array.isArray(rawCoordinates))
    return null;
  const distance = (summary as Record<string, unknown>).distance;
  const duration = (summary as Record<string, unknown>).duration;
  if (
    typeof distance !== 'number' ||
    typeof duration !== 'number' ||
    distance <= 0 ||
    duration <= 0
  )
    return null;
  const coordinates = rawCoordinates.flatMap(
    (point): Array<[number, number]> => {
      if (
        !Array.isArray(point) ||
        point.length < 2 ||
        typeof point[0] !== 'number' ||
        typeof point[1] !== 'number'
      )
        return [];
      return [[point[0], point[1]]];
    },
  );
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
  return Array.from(
    { length: maximumPoints },
    (_, index) => coordinates[Math.round(index * step)],
  );
}
