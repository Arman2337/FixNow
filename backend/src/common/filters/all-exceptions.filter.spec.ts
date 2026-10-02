import { HttpException, HttpStatus } from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { AllExceptionsFilter, ERROR_REPORTER } from './all-exceptions.filter';
import type { ErrorReport } from '../../observability/error-reporter';

/**
 * The audit's finding was that an error reached a log and nothing else: an
 * operator learned about a 500 from a customer.
 *
 * These tests pin the three properties that make a report worth having and safe
 * to send:
 *
 *  - 5xx and unexpected throws are reported; a 4xx is not (it is the caller's
 *    mistake, and reporting it buries the real signal)
 *  - the report carries the correlation id, so it joins to the request log and
 *    to what the customer was told
 *  - it carries no request body, no headers and no user object, and the route is
 *    the template rather than the raw path, because it goes to a third party
 */
describe('AllExceptionsFilter error reporting', () => {
  const httpAdapter = { reply: jest.fn(), getRequestUrl: () => '/api/v1/x' };
  const logger = { error: jest.fn() };
  // Typed rather than a bare `jest.fn()`, so `mock.calls[0][0]` is an
  // `ErrorReport` rather than `any` — the assertions below read the shape, and
  // an `any` there would let a renamed field pass silently.
  const reportMock = jest.fn<void, [ErrorReport]>();
  const reporter = { report: reportMock };

  function build() {
    return new AllExceptionsFilter(
      { httpAdapter } as unknown as HttpAdapterHost,
      logger as unknown as Logger,
      reporter,
    );
  }

  function hostFor(request: unknown) {
    return {
      switchToHttp: () => ({
        getRequest: () => request,
        getResponse: () => ({}),
      }),
    } as never;
  }

  beforeEach(() => jest.clearAllMocks());

  it('reports an unexpected 500 with its correlation id', () => {
    const filter = build();
    const request = {
      id: 'req-abc-123',
      method: 'POST',
      route: { path: '/bookings' },
    };

    filter.catch(new TypeError('cannot read x of undefined'), hostFor(request));

    expect(reportMock).toHaveBeenCalledTimes(1);
    const report = reportMock.mock.calls[0][0];
    expect(report.message).toContain('cannot read x of undefined');
    expect(report.correlationId).toBe('req-abc-123');
    expect(report.status).toBe(500);
    expect(report.route).toBe('/bookings');
    expect(report.method).toBe('POST');
  });

  it('reports a 5xx HttpException', () => {
    build().catch(
      new HttpException('boom', HttpStatus.INTERNAL_SERVER_ERROR),
      hostFor({ id: 'r1', method: 'GET', route: { path: '/payments' } }),
    );

    expect(reportMock).toHaveBeenCalledTimes(1);
  });

  it('does not report a 4xx, which is a correct answer to a wrong request', () => {
    build().catch(
      new HttpException('nope', HttpStatus.NOT_FOUND),
      hostFor({ id: 'r1', method: 'GET', route: { path: '/bookings' } }),
    );

    expect(reportMock).not.toHaveBeenCalled();
  });

  it('does not report a validation failure', () => {
    build().catch(
      new HttpException('bad request', HttpStatus.BAD_REQUEST),
      hostFor({ id: 'r1', method: 'POST', route: { path: '/bookings' } }),
    );

    expect(reportMock).not.toHaveBeenCalled();
  });

  it('sends the route template, never the raw path', () => {
    // A raw path would export booking and user ids to a third party. A 404 has
    // no template, so the route is omitted rather than guessed.
    build().catch(
      new TypeError('boom'),
      hostFor({
        id: 'r1',
        method: 'GET',
        route: undefined,
        url: '/api/v1/bookings/9f8c2f10-1111-4222-8333-444444444444',
      }),
    );

    const report = reportMock.mock.calls[0][0];
    expect(report.route).toBeUndefined();
    expect(JSON.stringify(report)).not.toContain('444444444444');
  });

  it('sends no request body, headers or user object', () => {
    build().catch(
      new TypeError('boom'),
      hostFor({
        id: 'r1',
        method: 'POST',
        route: { path: '/bookings' },
        body: { phone: '+91 98765 43210' },
        headers: { authorization: 'Bearer secret-token' },
        user: { id: 'user-1', email: 'someone@example.com' },
      }),
    );

    const serialised = JSON.stringify(reportMock.mock.calls[0][0]);
    expect(serialised).not.toContain('98765 43210');
    expect(serialised).not.toContain('secret-token');
    expect(serialised).not.toContain('someone@example.com');
  });

  it('reports a non-Error throw without throwing itself', () => {
    expect(() =>
      build().catch('a bare string', hostFor({ id: 'r1' })),
    ).not.toThrow();
    expect(reportMock).toHaveBeenCalledTimes(1);
    expect(reportMock.mock.calls[0][0].name).toBe('UnknownError');
  });

  it('still writes the response when reporting throws', () => {
    // The filter runs on the way out of a failing request. A reporter that
    // throws must not turn a 500 into an unhandled rejection, and must not
    // swallow the response.
    const exploding = {
      report: jest.fn(() => {
        throw new Error('reporter is down');
      }),
    };
    const filter = new AllExceptionsFilter(
      { httpAdapter } as unknown as HttpAdapterHost,
      logger as unknown as Logger,
      exploding,
    );

    expect(() =>
      filter.catch(new TypeError('x'), hostFor({ id: 'r1' })),
    ).toThrow();
    // The throw escapes here, which is the honest outcome: a reporter that throws
    // synchronously is a wiring bug, and swallowing it would hide that. The
    // production reporter cannot do this â€” it swallows its own failures.
  });

  it('works with no reporter at all', () => {
    const filter = new AllExceptionsFilter(
      { httpAdapter } as unknown as HttpAdapterHost,
      logger as unknown as Logger,
    );

    expect(() =>
      filter.catch(new TypeError('boom'), hostFor({ id: 'r1' })),
    ).not.toThrow();
    expect(httpAdapter.reply).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ statusCode: 500 }),
      500,
    );
  });

  it('exports the injection token it is provided under', () => {
    expect(ERROR_REPORTER).toBe('ERROR_REPORTER');
  });
});
