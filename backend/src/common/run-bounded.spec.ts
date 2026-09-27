import { runBounded } from './run-bounded';

const tick = (): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, 1));

describe('runBounded', () => {
  it('runs every item exactly once', async () => {
    const items = Array.from({ length: 25 }, () =>
      jest.fn(async () => undefined),
    );

    await runBounded(
      items.map((item) => item as () => Promise<unknown>),
      4,
    );

    for (const item of items) {
      expect(item).toHaveBeenCalledTimes(1);
    }
  });

  it('never exceeds the concurrency limit', async () => {
    let inFlight = 0;
    let peak = 0;
    const work = Array.from({ length: 30 }, () => async () => {
      inFlight += 1;
      peak = Math.max(peak, inFlight);
      await tick();
      inFlight -= 1;
    });

    await runBounded(work, 5);

    expect(peak).toBeLessThanOrEqual(5);
    // Concurrency, not serialisation.
    expect(peak).toBeGreaterThan(1);
  });

  it('does not start an item before a slot is free', async () => {
    // The contract that matters: thunks, not promises. If the caller passed
    // started promises this helper could not possibly bound them.
    const started: number[] = [];
    const work = Array.from({ length: 6 }, (_, index) => async () => {
      started.push(index);
      await tick();
    });

    await runBounded(work, 2);

    expect(started).toHaveLength(6);
    expect(Math.max(...started)).toBe(5);
  });

  it('keeps going after an item rejects, and never throws', async () => {
    const after = jest.fn(async () => undefined);
    const work = [
      async () => {
        throw new Error('boom');
      },
      after,
    ];

    await expect(runBounded(work, 1)).resolves.toBeUndefined();
    expect(after).toHaveBeenCalled();
  });

  it('tolerates a nonsense concurrency value', async () => {
    const item = jest.fn(async () => undefined);
    await runBounded([item], 0);
    await runBounded([item], -5);
    expect(item).toHaveBeenCalledTimes(2);
  });

  it('handles an empty batch', async () => {
    await expect(runBounded([], 10)).resolves.toBeUndefined();
  });
});
