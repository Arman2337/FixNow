import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { Logger } from 'nestjs-pino';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  constructor(
    private readonly httpAdapterHost: HttpAdapterHost,
    private readonly logger: Logger,
  ) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const { httpAdapter } = this.httpAdapterHost;
    const ctx = host.switchToHttp();

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
    };

    httpAdapter.reply(ctx.getResponse(), responseBody, httpStatus);
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
