import { BoundedFallbackEtaAdapter } from './eta-adapter';

describe('BoundedFallbackEtaAdapter', () => {
  const adapter = new BoundedFallbackEtaAdapter();

  it('returns a bounded explicitly sourced estimate', async () => {
    const estimate = await adapter.estimate({
      providerLatitude: 22.3072,
      providerLongitude: 73.1812,
      destinationLatitude: 22.3172,
      destinationLongitude: 73.1912,
    });
    expect(estimate).not.toBeNull();
    expect(estimate?.estimatedMinutes).toBeGreaterThan(0);
    expect(estimate?.source).toBe('bounded-distance-fallback');
  });

  it('returns unavailable instead of promising an extreme ETA', async () => {
    await expect(
      adapter.estimate({
        providerLatitude: 0,
        providerLongitude: 0,
        destinationLatitude: 50,
        destinationLongitude: 50,
      }),
    ).resolves.toBeNull();
  });
});
