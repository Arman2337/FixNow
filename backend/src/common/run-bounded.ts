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
  if (work.length === 0) return;
  const limit = Math.max(1, Math.min(Math.trunc(concurrency), work.length));
  let next = 0;

  const worker = async (): Promise<void> => {
    while (next < work.length) {
      const index = next;
      next += 1;
      try {
        await work[index]();
      } catch {
        // Best-effort by contract; see the note above.
      }
    }
  };

  await Promise.all(Array.from({ length: limit }, worker));
}
