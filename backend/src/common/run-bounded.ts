/**
 * Runs thunks with a bounded number in flight.
 *
 * Two properties matter, and the second is the one that is easy to get wrong:
 *
 * 1. It bounds concurrency. Awaiting work items one at a time serialises the
 *    batch, so a single slow dependency stalls everything behind it; running
 *    everything at once can open thousands of sockets at a downstream provider.
 *
 * 2. It takes **thunks**, not promises. An array of already-started promises is
 *    fully in flight before this function is even called, so a bounded `await`
 *    over one bounds nothing. Each item must be a function so nothing starts
 *    until a slot is free.
 *
 * Failures are swallowed deliberately: every caller uses this for
 * best-effort side effects where one failure must not abandon the rest of the
 * batch or fail the operation that triggered it.
 */
export async function runBounded(
  work: ReadonlyArray<() => Promise<unknown>>,
  concurrency: number,
): Promise<void> {
  await mapBounded(work, concurrency);
}

/**
 * Like {@link runBounded}, but collects the results **in input order**.
 *
 * A bounded pool finishes out of order, so a caller that needs its results
 * positionally must not read completion order. A failed item yields `undefined`
 * rather than rejecting, so one failure cannot abandon the batch.
 */
export async function mapBounded<T>(
  work: ReadonlyArray<() => Promise<T>>,
  concurrency: number,
): Promise<Array<T | undefined>> {
  // `new Array(n)` is `any[]`; the fill below is what actually types it.
  const results: Array<T | undefined> = Array.from<T | undefined>({
    length: work.length,
  });
  if (work.length === 0) return results;
  const limit = Math.max(1, Math.min(Math.trunc(concurrency), work.length));
  let next = 0;

  const worker = async (): Promise<void> => {
    while (next < work.length) {
      const index = next;
      next += 1;
      try {
        results[index] = await work[index]();
      } catch {
        results[index] = undefined;
      }
    }
  };

  await Promise.all(Array.from({ length: limit }, worker));
  return results;
}
