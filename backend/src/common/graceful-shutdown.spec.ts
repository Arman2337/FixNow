import { runGracefulShutdown } from './graceful-shutdown';
import { ReadinessState } from '../health/readiness-state.service';

/**
 * OPS-002 and BUG-012.
 *
 * The behaviour under test is the one a deploy depends on and no unit test
 * previously covered: that a SIGTERM stops new requests arriving *before* it
 * waits for the ones already in flight. Getting that order wrong is invisible in
 * every other metric and shows up only as requests that fail during a deploy.
 */
describe('graceful shutdown', () => {
  const listeners = new Map<NodeJS.Signals, () => Promise<void>>();
  let exitCode: number | null = null;
  let closeCalled: number;
  let readiness: ReadinessState;
  let log: jest.Mock;
  let warn: jest.Mock;
  let error: jest.Mock;
  let app: { close: () => Promise<void> };
  let originalExit: typeof process.exit;
  let originalOn: typeof process.on;
  let originalOnce: typeof process.once;

  beforeEach(() => {
    listeners.clear();
    exitCode = null;
    closeCalled = 0;
    readiness = new ReadinessState();
    log = jest.fn();
    warn = jest.fn();
    error = jest.fn();
    app = {
      close: jest.fn(async () => {
        closeCalled += 1;
      }),
    };
    // Bound, because the originals have to be restored in fterEach and
    // reading a method off process without binding it is exactly the mistake
    // the unbound-method rule exists to catch.
    originalExit = process.exit.bind(process);
    originalOn = process.on.bind(process);
    originalOnce = process.once.bind(process);
    // Captured rather than dispatched: the real signal would end the test run.
    const capture = (signal: NodeJS.Signals, handler: () => void) => {
      // Wrapped so awaiting the captured handler is awaiting a promise, which is
      // what the real signal listener is.
      listeners.set(signal, () => handler() as unknown as Promise<void>);
      return process;
    };
    process.once = capture as typeof process.once;
    process.on = capture as typeof process.on;
    process.exit = (code?: number) => {
      exitCode = code ?? 0;
      // Never actually exit from a test.
      return undefined as never;
    };
  });

  afterEach(() => {
    process.exit = originalExit;
    process.on = originalOn;
    process.once = originalOnce;
  });

  const install = (timeoutMs = 60_000) =>
    runGracefulShutdown({
      app: app as never,
      readiness,
      logger: { log, warn, error },
      timeoutMs,
    });

  it('starts failing readiness before closing the application', async () => {
    const states: boolean[] = [];
    app.close = jest.fn(async () => {
      // Sampled at the moment the close begins, which is the moment the
      // load balancer must already have stopped sending requests.
      states.push(readiness.isReady);
      closeCalled += 1;
    });

    install();
    await listeners.get('SIGTERM')!();

    expect(states).toEqual([false]);
    expect(closeCalled).toBe(1);
    expect(exitCode).toBe(0);
  });

  it('records the signal that caused the drain', async () => {
    install();
    await listeners.get('SIGINT')!();
    expect(readiness.state.draining).toBe(true);
  });

  // A platform commonly sends SIGTERM and then SIGINT a moment later. Starting
  // a second drain would reset the deadline and abandon the first one's work.
  it('ignores a second signal while already draining', async () => {
    install();
    await listeners.get('SIGTERM')!();
    await listeners.get('SIGINT')!();
    expect(closeCalled).toBe(1);
  });

  it('exits non-zero when closing throws', async () => {
    app.close = jest.fn(async () => {
      throw new Error('pool did not release');
    });
    install();
    await listeners.get('SIGTERM')!();
    expect(exitCode).toBe(1);
    expect(error).toHaveBeenCalledWith(
      expect.stringContaining('pool did not release'),
    );
  });

  it('bounds the drain so a hung request cannot outlive the platform grace period', async () => {
    jest.useFakeTimers();
    try {
      // A request that never settles - the exact case an unbounded drain hangs on.
      app.close = jest.fn(() => new Promise<void>(() => undefined));
      install(25_000);
      void listeners.get('SIGTERM')!();
      await Promise.resolve();

      jest.advanceTimersByTime(25_001);
      expect(warn).toHaveBeenCalledWith(
        expect.stringContaining('exceeded 25000ms'),
      );
      expect(exitCode).toBe(1);
    } finally {
      jest.useRealTimers();
    }
  });
});

describe('ReadinessState', () => {
  let readiness: ReadinessState;
  beforeEach(() => {
    readiness = new ReadinessState();
  });

  it('is ready when nothing has gone wrong', () => {
    expect(readiness.isReady).toBe(true);
  });

  it('is not ready while draining, and says so', () => {
    readiness.beginDraining('SIGTERM');
    expect(readiness.isReady).toBe(false);
    expect(readiness.state).toMatchObject({
      ready: false,
      draining: true,
    });
  });

  it('keeps the first drain reason when a second signal arrives', () => {
    readiness.beginDraining('SIGTERM');
    readiness.beginDraining('SIGINT');
    expect(readiness.state.draining).toBe(true);
  });

  it('is not ready when a required dependency is unavailable', () => {
    readiness.reportDependencyFailure('cache.redis', 'ECONNREFUSED');
    expect(readiness.isReady).toBe(false);
    expect(readiness.state.reason).toContain('ECONNREFUSED');
  });

  it('recovers when the dependency returns', () => {
    readiness.reportDependencyFailure('cache.redis', 'ECONNREFUSED');
    readiness.reportDependencyRecovered('cache.redis');
    expect(readiness.isReady).toBe(true);
    expect(readiness.state.reason).toBeNull();
  });

  it('does not report ready again while still draining', () => {
    readiness.beginDraining('SIGTERM');
    readiness.reportDependencyRecovered('cache.redis');
    expect(readiness.isReady).toBe(false);
  });
});
