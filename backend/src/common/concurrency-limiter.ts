/**
 * A counting semaphore with a non-blocking acquire.
 *
 * The reason this is a semaphore and not a queue is memory. Whatever
 * `tryAcquire` rejects never gets a slot, so whatever it was holding can be
 * released; a queue would hold every arrival and spread the same peak over
 * time, which bounds nothing.
 *
 * `tryAcquire` is non-blocking on purpose for a second reason: the caller has
 * usually *already* paid the memory cost by the time it can ask. Multer's
 * memory storage buffers the whole multipart body before the route handler
 * runs, so by the time application code sees a 50 MiB upload that 50 MiB is
 * resident regardless. What this bounds is how many such buffers are resident
 * *at once* - which is the difference between `capacity x per-file-cap` and
 * unbounded, and unbounded is how a handful of concurrent callers OOM a
 * container.
 */
export class ConcurrencyLimiter {
  private inFlight = 0;

  constructor(private readonly capacity: number) {
    if (!Number.isInteger(capacity) || capacity < 1) {
      throw new Error('ConcurrencyLimiter capacity must be a positive integer');
    }
  }

  tryAcquire(): boolean {
    if (this.inFlight >= this.capacity) return false;
    this.inFlight += 1;
    return true;
  }

  release(): void {
    if (this.inFlight > 0) this.inFlight -= 1;
  }

  get active(): number {
    return this.inFlight;
  }

  /** Runs `work` while holding a slot, or returns `undefined` when full. */
  async run<T>(work: () => Promise<T>): Promise<T | undefined> {
    if (!this.tryAcquire()) return undefined;
    try {
      return await work();
    } finally {
      this.release();
    }
  }
}
