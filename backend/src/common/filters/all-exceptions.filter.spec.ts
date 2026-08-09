import { ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { AllExceptionsFilter } from './all-exceptions.filter';

describe('AllExceptionsFilter', () => {
  const reply = jest.fn();
  const loggerError = jest.fn();
  const argumentsHost = {
    switchToHttp: jest.fn().mockReturnValue({
      getRequest: jest.fn(),
      getResponse: jest.fn(),
    }),
  } as unknown as ArgumentsHost;
  const httpAdapterHost = {
    httpAdapter: {
      getRequestUrl: jest.fn().mockReturnValue('/test-url'),
      reply,
    },
  } as unknown as HttpAdapterHost;
  const logger = { error: loggerError } as unknown as Logger;
  const filter = new AllExceptionsFilter(httpAdapterHost, logger);

  beforeEach(() => jest.clearAllMocks());

  it('formats an HttpException without logging it as an internal error', () => {
    filter.catch(
      new HttpException('Bad Request', HttpStatus.BAD_REQUEST),
      argumentsHost,
    );

    expect(reply).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({
        statusCode: HttpStatus.BAD_REQUEST,
        message: 'Bad Request',
        path: '/test-url',
      }),
      HttpStatus.BAD_REQUEST,
    );
    expect(loggerError).not.toHaveBeenCalled();
  });

  it('preserves safe validation message arrays', () => {
    filter.catch(
      new HttpException(
        { message: ['name is required'] },
        HttpStatus.BAD_REQUEST,
      ),
      argumentsHost,
    );

    expect(reply).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({ message: ['name is required'] }),
      HttpStatus.BAD_REQUEST,
    );
  });

  it('hides and logs unknown exceptions', () => {
    const exception = new Error('Database connection failed');
    filter.catch(exception, argumentsHost);

    expect(reply).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({
        statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
        message: 'Internal server error',
        path: '/test-url',
      }),
      HttpStatus.INTERNAL_SERVER_ERROR,
    );
    expect(loggerError).toHaveBeenCalledWith(exception);
  });
});
