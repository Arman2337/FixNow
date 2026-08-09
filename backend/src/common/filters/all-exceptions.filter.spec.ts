import { AllExceptionsFilter } from './all-exceptions.filter';
import { HttpException, HttpStatus } from '@nestjs/common';

describe('AllExceptionsFilter', () => {
  let filter: AllExceptionsFilter;
  let mockHttpAdapterHost: any;
  let mockLogger: any;
  let mockArgumentsHost: any;
  let mockHttpAdapter: any;

  beforeEach(() => {
    mockHttpAdapter = {
      getRequestUrl: jest.fn().mockReturnValue('/test-url'),
      reply: jest.fn(),
    };

    mockHttpAdapterHost = {
      httpAdapter: mockHttpAdapter,
    };

    mockLogger = {
      error: jest.fn(),
    };

    filter = new AllExceptionsFilter(mockHttpAdapterHost, mockLogger);

    mockArgumentsHost = {
      switchToHttp: jest.fn().mockReturnValue({
        getRequest: jest.fn(),
        getResponse: jest.fn(),
      }),
    };
  });

  it('should format HttpException correctly', () => {
    const exception = new HttpException('Bad Request', HttpStatus.BAD_REQUEST);
    filter.catch(exception, mockArgumentsHost);

    expect(mockHttpAdapter.reply).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({
        statusCode: HttpStatus.BAD_REQUEST,
        message: 'Bad Request',
        path: '/test-url',
      }),
      HttpStatus.BAD_REQUEST,
    );
    // Should not log expected http exceptions as standard errors
    expect(mockLogger.error).not.toHaveBeenCalled();
  });

  it('should format unknown exceptions as 500 Internal Server Error and log them', () => {
    const exception = new Error('Database connection failed');
    filter.catch(exception, mockArgumentsHost);

    expect(mockHttpAdapter.reply).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({
        statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
        message: 'Internal server error',
        path: '/test-url',
      }),
      HttpStatus.INTERNAL_SERVER_ERROR,
    );
    // Should log unexpected internal errors
    expect(mockLogger.error).toHaveBeenCalledWith(exception);
  });
});
