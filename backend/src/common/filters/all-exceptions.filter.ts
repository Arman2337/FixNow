import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Optional,
  Inject,
} from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import type { ErrorReporter } from '../../observability/error-reporter';

/**
 * The token the reporter is provided under.
 *
 * A string token rather than the class so the filter does not import the
 * transport, which keeps the filter's dependency set to one interface — the
 * filter is the component most likely to be the last thing that works during an
 * incident, so it should depend on as little as possible.
 */
export const ERROR_REPORTER = 'ERROR_REPORTER';

/** The status at and above which a failure is a defect rather than a refusal. */
const SERVER_ERROR_STATUS = 500;

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  constructor(
    private readonly httpAdapterHost: HttpAdapterHost,
    private readonly logger: Logger,
    // Optional so a unit test that builds this filter alone does not have to
    // know about reporting; the application always provides one.
    @Optional()
    @Inject(ERROR_REPORTER)
    private readonly reporter?: ErrorReporter,
  ) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const { httpAdapter } = this.httpAdapterHost;
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<{
      id?: unknown;
      method?: unknown;
      route?: { path?: unknown };
    }>();
    const correlationId =
      typeof request?.id === 'string' && request.id ? request.id : undefined;

    let httpStatus = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';

    if (exception instanceof HttpException) {
      httpStatus = exception.getStatus();
      message = this.getHttpExceptionMessage(exception);
    } else {
      // Log the full stack trace securely for unexpected internal errors
      this.logger.error(exception);
    }

    const responseBody = {
      statusCode: httpStatus,
      message,
      timestamp: new Date().toISOString(),
      path: String(httpAdapter.getRequestUrl(ctx.getRequest<unknown>())),
      // A09: the id the client was already sent in X-Request-Id, repeated in
      // the body for clients that surface only the parsed error. A 5xx report
      // without it is not actionable.
      ...(correlationId ? { correlationId } : {}),
    };

    // A 5xx, or an unexpected non-Http exception, is worth a report. A 4xx is
    // the caller's mistake and reporting it would bury the real signal — the
    // client asked for something that does not exist, and that is a correct
    // answer, not an incident.
    if (this.isReportable(exception, httpStatus)) {
      this.report(exception, correlationId, request, httpStatus);
    }

    httpAdapter.reply(ctx.getResponse(), responseBody, httpStatus);
  }

  /**
   * Is this the kind of failure an on-call engineer should be woken for?
   *
   * The line is drawn at 5xx plus "not an `HttpException` at all". A thrown
   * `NotFoundException` is a correct response to a wrong request; a thrown
   * `TypeError` is a defect regardless of the status it happened to be given.
   */
  private isReportable(exception: unknown, httpStatus: number): boolean {
    if (!(exception instanceof HttpException)) return true;
    // Compared against the numeric value rather than the enum member: `HttpStatus`
    // is a heterogeneous enum, so `number >= HttpStatus.X` is not a comparison
    // TypeScript can prove anything about. The literal is the documented boundary.
    return httpStatus >= SERVER_ERROR_STATUS;
  }

  /**
   * Fire-and-forget.
   *
   * Not awaited, deliberately: this runs on the way out of a failing request, and
   * making the response wait on a third-party HTTP call would mean a slow
   * reporter adds latency to an incident. `HttpErrorReporter` swallows its own
   * failures, so there is nothing to handle — and a rejection here could not be
   * handled anyway, since the response is already being written.
   */
  private report(
    exception: unknown,
    correlationId: string | undefined,
    request: { method?: unknown; route?: { path?: unknown } },
    httpStatus: number,
  ): void {
    if (!this.reporter) return;
    const error = exception instanceof Error ? exception : undefined;
    void this.reporter.report({
      message: error?.message ?? 'Unknown error',
      name: error?.name ?? 'UnknownError',
      ...(error?.stack ? { stack: error.stack } : {}),
      ...(correlationId ? { correlationId } : {}),
      // The route *template*, never the raw path: a raw path would export
      // booking and user ids to a third party, which is a data export nobody
      // reviewed.
      route: describeRoute(request.route?.path),
      ...(typeof request.method === 'string' ? { method: request.method } : {}),
      status: httpStatus,
      environment: process.env.NODE_ENV ?? 'development',
      occurredAt: new Date().toISOString(),
    });
  }

  private getHttpExceptionMessage(exception: HttpException): string | string[] {
    const response: unknown = exception.getResponse();
    if (typeof response === 'string') return response;
    if (
      typeof response !== 'object' ||
      response === null ||
      !('message' in response)
    ) {
      return exception.message;
    }

    const message: unknown = response.message;
    if (typeof message === 'string') return message;
    if (
      Array.isArray(message) &&
      message.every((item) => typeof item === 'string')
    ) {
      return message;
    }
    return exception.message;
  }
}

/**
 * The route template for a report, or `undefined`.
 *
 * Express's `req.route.path` is the matched pattern (`/bookings/:id`), which is
 * safe to send. Anything else — a 404, a request that never matched a route — has
 * no template, and falling back to the raw path would put an attacker-supplied
 * string into a third-party system.
 */
function describeRoute(path: unknown): string | undefined {
  if (typeof path === 'string' && path.length > 0) return path;
  if (Array.isArray(path)) {
    const parts = path.filter(
      (part): part is string => typeof part === 'string',
    );
    return parts.length > 0 ? parts.join('|') : undefined;
  }
  return undefined;
}
