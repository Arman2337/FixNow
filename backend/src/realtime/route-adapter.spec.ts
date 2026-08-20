import { parseOpenRouteServiceRoute } from './route-adapter';

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
