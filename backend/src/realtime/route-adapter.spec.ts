import { ConfigService } from '@nestjs/config';
import { parseOpenRouteServiceRoute, OpenRouteServiceAdapter, haversineMeters } from './route-adapter';
import type { EtaInput } from './eta-adapter';

function geoJson(distance: number): unknown {
  return {
    features: [
      {
        properties: { summary: { distance, duration: 240 } },
        geometry: {
          coordinates: [
            [73.0701, 23.0269],
            [73.08, 23.033],
          ],
        },
      },
    ],
  };
}

const ORIGIN: EtaInput = {
  providerLatitude: 23.0269,
  providerLongitude: 73.0701,
  destinationLatitude: 23.033,
  destinationLongitude: 73.08,
};

function config(env: Record<string, string> = { OPENROUTESERVICE_API_KEY: 'test-key' }) {
  return { get: (key: string) => env[key] } as unknown as ConfigService;
}

describe('parseOpenRouteServiceRoute', () => {
  it('returns a compact driving route from an OpenRouteService GeoJSON response', () => {
    const route = parseOpenRouteServiceRoute({
      features: [
        {
          properties: { summary: { distance: 1840.5, duration: 420.2 } },
          geometry: {
            coordinates: [
              [72.99, 22.89],
              [73.01, 22.93],
            ],
          },
        },
      ],
    });

    expect(route).toEqual({
      distanceMeters: 1840.5,
      durationSeconds: 420.2,
      coordinates: [
        [72.99, 22.89],
        [73.01, 22.93],
      ],
    });
  });

  it('rejects malformed route responses', () => {
    expect(parseOpenRouteServiceRoute({ features: [] })).toBeNull();
  });
});

describe('haversineMeters', () => {
  it('measures a known short hop', () => {
    // ~111 m per 0.001 degree of latitude.
    expect(haversineMeters(23.0269, 73.0701, 23.0279, 73.0701)).toBeCloseTo(
      111,
      0,
    );
  });
});

describe('OpenRouteServiceAdapter', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  it('does not call the external service without a key', async () => {
    const fetchMock = jest.fn();
    global.fetch = fetchMock as unknown as typeof fetch;

    const adapter = new OpenRouteServiceAdapter(config({}));

    await expect(adapter.route(ORIGIN)).resolves.toBeNull();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  // Regression: live GPS arrives every 11s against a 200/day quota, so an
  // unrouted adapter exhausted the budget in half an hour and the app silently
  // fell back to a straight line.
  it('reuses the route while the technician has not moved', async () => {
    const fetchMock = jest.fn(async () => ({
      ok: true,
      status: 200,
      text: async () => JSON.stringify(geoJson(1527.6)),
    }));
    global.fetch = fetchMock as unknown as typeof fetch;

    const adapter = new OpenRouteServiceAdapter(config());

    const first = await adapter.route(ORIGIN);
    // A few metres of GPS drift, then a second publish 11s later.
    const second = await adapter.route({
      ...ORIGIN,
      providerLatitude: 23.0270,
      providerLongitude: 73.07015,
    });

    expect(first?.distanceMeters).toBe(1527.6);
    expect(second).toBe(first);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('refetches once the technician has moved beyond the threshold', async () => {
    const fetchMock = jest.fn(async () => ({
      ok: true,
      status: 200,
      text: async () => JSON.stringify(geoJson(1527.6)),
    }));
    global.fetch = fetchMock as unknown as typeof fetch;

    const adapter = new OpenRouteServiceAdapter(config());

    await adapter.route(ORIGIN);
    await adapter.route({
      ...ORIGIN,
      providerLatitude: 23.0369,
      providerLongitude: 73.0701,
    });

    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('collapses concurrent publishes into one external request', async () => {
    const fetchMock = jest.fn(async () => ({
      ok: true,
      status: 200,
      text: async () => JSON.stringify(geoJson(1527.6)),
    }));
    global.fetch = fetchMock as unknown as typeof fetch;

    const adapter = new OpenRouteServiceAdapter(config());

    await Promise.all([adapter.route(ORIGIN), adapter.route(ORIGIN)]);

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('keeps serving the cached route when the quota is exhausted', async () => {
    const fetchMock = jest
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        text: async () => JSON.stringify(geoJson(1527.6)),
      })
      .mockResolvedValue({ ok: false, status: 429, text: async () => '' });
    global.fetch = fetchMock as unknown as typeof fetch;

    const adapter = new OpenRouteServiceAdapter(config());

    const first = await adapter.route(ORIGIN);
    // Provider has moved far, so a refresh is attempted and rejected by ORS.
    const second = await adapter.route({
      ...ORIGIN,
      providerLatitude: 23.0369,
      providerLongitude: 73.0701,
    });

    expect(first).not.toBeNull();
    expect(second).toEqual(first);
  });

  it('returns null when the very first request fails', async () => {
    global.fetch = jest.fn(async () => ({
      ok: false,
      status: 500,
      text: async () => '',
    })) as unknown as typeof fetch;

    const adapter = new OpenRouteServiceAdapter(config());

    await expect(adapter.route(ORIGIN)).resolves.toBeNull();
  });

  it('honours configured refresh thresholds', async () => {
    const fetchMock = jest.fn(async () => ({
      ok: true,
      status: 200,
      text: async () => JSON.stringify(geoJson(1527.6)),
    }));
    global.fetch = fetchMock as unknown as typeof fetch;

    const adapter = new OpenRouteServiceAdapter(
      config({
        OPENROUTESERVICE_API_KEY: 'test-key',
        ROUTE_REFRESH_MIN_METERS: '1000',
      }),
    );

    await adapter.route(ORIGIN);
    // ~570 m: far beyond the 50 m default, but under the configured 1000 m.
    await adapter.route({
      ...ORIGIN,
      providerLatitude: 23.032,
      providerLongitude: 73.0701,
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
