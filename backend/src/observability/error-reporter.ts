import { Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';

/**
 * One reportable error, shaped deliberately.
 *
 * This is the wire format the transport below posts, written out as an interface
 * so the shape is reviewable and testable without a network call. The fields are
 * the minimum an on-call engineer needs and nothing else:
 *
 *  - `correlationId` is the load-bearing one. It is already echoed to the client
 *    in `x-request-id`, so an operator reading a support ticket can join this
 *    report to the request log and to the customer-visible error, which is what
 *    makes a report actionable rather than merely alarming.
 *  - `route` is the *template*, never the raw path. A raw path would put booking
 *    and user ids into a third-party service, which is a data export that nobody
 *    reviewed.
 *  - There is no request body, no header set and no user object, for the same
 *    reason. A report that contains a phone number or an address is a report
 *    that cannot be forwarded.
 */
export interface ErrorReport {
  readonly message: string;
  readonly name: string;
  readonly stack?: string;
  readonly correlationId?: string;
  readonly route?: string;
  readonly method?: string;
  readonly status?: number;
  readonly environment: string;
  readonly release?: string;
  readonly occurredAt: string;
}

/**
 * Where reports go.
 *
 * An interface rather than a concrete client so the transport is swappable and
 * so a test can assert what would be sent without a network. The audit's
 * finding was that errors reached a log and nothing else — an operator learned
 * about a 500 from a customer.
 */
export interface ErrorReporter {
  report(report: ErrorReport): void | Promise<void>;
}

/**
 * Reports to Sentry's ingest endpoint over plain HTTPS.
 *
 * Deliberately dependency-free, for the same reason the metrics registry is:
 * `@sentry/node` is the right choice at a scale where someone maintains that
 * dependency, and this is ~60 lines that anyone can read. The transport is
 * `fetch` with a fire-and-forget call, so a slow or failing error reporter can
 * never add latency to a request — the failure mode of an observability tool must
 * not be the outage it exists to explain.
 *
 * Reports are best-effort by design. If Sentry is unreachable the report is
 * dropped and logged at debug, never retried: a queued error report is a memory
 * leak with a 500 in it.
 */
@Injectable()
export class HttpErrorReporter implements ErrorReporter {
  private readonly logger = new Logger(HttpErrorReporter.name);

  constructor(
    private readonly dsn: string,
    private readonly environment: string,
    private readonly release?: string,
  ) {}

  async report(report: ErrorReport): Promise<void> {
    const url = this.ingestUrl(this.dsn);
    if (!url) {
      this.logger.debug(
        'Error report discarded: the DSN is not a usable Sentry DSN. The error ' +
          'is already in the structured log.',
      );
      return;
    }
    try {
      await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // `envelope()` already returns the two NDJSON lines. Encoding it again
        // would produce a JSON string *containing* an envelope, which the
        // receiver silently discards — and a discarded envelope is
        // indistinguishable from an application that never had an error at all.
        body: this.envelope(report) as unknown as BodyInit,
        // No credentials and no cookies: this goes to a third party.
        keepalive: true,
        // A bounded attempt. An error reporter that can hang is worse than none.
        signal: AbortSignal.timeout(3_000),
      });
    } catch (error) {
      // Swallowed deliberately, and logged at debug. Throwing here would turn a
      // failed report into a second failure on the same request.
      this.logger.debug(
        // `cause` is a real `unknown`, narrowed to the Error shape pino expects,
        // so the debug line is useful without being a second thing that can throw.
        { err: error instanceof Error ? error : new Error(String(error)) },
        'Error report could not be delivered; the structured log is authoritative.',
      );
    }
  }

  /**
   * The Sentry envelope: a header line plus one item line.
   *
   * Hand-built rather than `JSON.stringify` of an object because the format is a
   * two-line NDJSON envelope, and a subtly wrong envelope is silently dropped by
   * the receiver — which would look exactly like "no errors are happening".
   */
  private envelope(report: ErrorReport): string {
    const header = JSON.stringify({
      event_id: randomUUID().replace(/-/g, ''),
      sent_at: new Date().toISOString(),
      dsn: this.dsn,
    });
    const item = JSON.stringify({
      type: 'event',
      content_type: 'application/json',
      // Varies by receiver: the Cloudflare `tunnel` endpoint expects the event
      // at the top level, and this is the shape its `/api/{project}/envelope/`
      // route documents.
      ...report,
      platform: 'node',
    });
    return `${header}\n${item}\n`;
  }

  private ingestUrl(dsn: string): string | null {
    try {
      const parsed = new URL(dsn);
      if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
        return null;
      }
      const publicKey = parsed.username;
      const projectId = parsed.pathname.replace(/^\//, '');
      if (!publicKey || !projectId) return null;
      const origin =
        parsed.protocol === 'https:' ? 'https://sentry.io' : parsed.origin;
      return `${origin}/api/${projectId}/envelope/`;
    } catch {
      return null;
    }
  }
}

/**
 * Drops everything.
 *
 * The default when no DSN is configured, which is the correct behaviour for local
 * development and for any environment that has not been given a DSN: the
 * structured log already carries the error, and a local developer does not need
 * it sent to a third party.
 */
@Injectable()
export class NoopErrorReporter implements ErrorReporter {
  report(): void {
    // Intentionally empty. See the class comment.
  }
}
