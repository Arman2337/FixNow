import { ConcurrencyLimiter } from './concurrency-limiter';

const tick = (): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, 1));

describe('ConcurrencyLimiter', () => {
  it('refuses work past capacity rather than queueing it', () => {
    const limiter = new ConcurrencyLimiter(2);

    expect(limiter.tryAcquire()).toBe(true);
    expect(limiter.tryAcquire()).toBe(true);
    expect(limiter.tryAcquire()).toBe(false);
    expect(limiter.active).toBe(2);
  });

  // The reason it rejects instead of queueing: a queue holds every arrival, so
  // peak memory is unchanged. Rejection lets a caller's buffer be released.
  it('frees a slot on release', () => {
    const limiter = new ConcurrencyLimiter(1);
    limiter.tryAcquire();

    expect(limiter.tryAcquire()).toBe(false);
    limiter.release();
    expect(limiter.tryAcquire()).toBe(true);
  });

  it('never exceeds capacity under concurrent load', async () => {
    const limiter = new ConcurrencyLimiter(3);
    let peak = 0;

    await Promise.all(
      Array.from({ length: 20 }, () =>
        limiter.run(async () => {
          peak = Math.max(peak, limiter.active);
          await tick();
        }),
      ),
    );

    expect(peak).toBeLessThanOrEqual(3);
    expect(limiter.active).toBe(0);
  });

  it('returns undefined for work it cannot admit', async () => {
    const limiter = new ConcurrencyLimiter(1);
    const admitted = limiter.run(() => tick().then(() => 'done'));

    await expect(limiter.run(async () => 'other')).resolves.toBeUndefined();
    await expect(admitted).resolves.toBe('done');
  });

  it('releases the slot when the work throws', async () => {
    const limiter = new ConcurrencyLimiter(1);

    await expect(
      limiter.run(async () => {
        throw new Error('boom');
      }),
    ).rejects.toThrow('boom');
    expect(limiter.active).toBe(0);
  });

  it('ignores an unbalanced release', () => {
    const limiter = new ConcurrencyLimiter(2);
    limiter.release();
    limiter.release();

    expect(limiter.active).toBe(0);
  });

  it('rejects a nonsensical capacity at construction', () => {
    expect(() => new ConcurrencyLimiter(0)).toThrow();
    expect(() => new ConcurrencyLimiter(-1)).toThrow();
    expect(() => new ConcurrencyLimiter(1.5)).toThrow();
  });
});
