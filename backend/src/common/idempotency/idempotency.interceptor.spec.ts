import { ExecutionContext, CallHandler } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Cache } from 'cache-manager';
import { of, lastValueFrom } from 'rxjs';
import { IdempotencyInterceptor } from './idempotency.interceptor';
import { IDEMPOTENT_KEY } from './idempotency.decorator';

describe('IdempotencyInterceptor', () => {
  let interceptor: IdempotencyInterceptor;
  let reflector: jest.Mocked<Reflector>;
  let cacheManager: jest.Mocked<Cache>;
  let mockContext: jest.Mocked<ExecutionContext>;
  let mockCallHandler: jest.Mocked<CallHandler>;
  let mockRequest: any;

  beforeEach(() => {
    reflector = {
      getAllAndOverride: jest.fn(),
    } as any;

    cacheManager = {
      get: jest.fn(),
      set: jest.fn(),
    } as any;

    interceptor = new IdempotencyInterceptor(reflector, cacheManager);

    mockRequest = {
      headers: {},
      method: 'POST',
      path: '/api/v1/bookings',
      authorizationPrincipal: { userId: 'user-id' },
    };

    mockContext = {
      getHandler: jest.fn(),
      getClass: jest.fn(),
      switchToHttp: jest.fn().mockReturnValue({
        getRequest: () => mockRequest,
      }),
    } as any;

    mockCallHandler = {
      handle: jest.fn().mockReturnValue(of({ data: 'new response' })),
    };
  });

  it('should bypass caching if endpoint is not decorated with @Idempotent', async () => {
    reflector.getAllAndOverride.mockReturnValue(false);

    const result = await lastValueFrom(await interceptor.intercept(mockContext, mockCallHandler));

    expect(result).toEqual({ data: 'new response' });
    expect(cacheManager.get).not.toHaveBeenCalled();
    expect(cacheManager.set).not.toHaveBeenCalled();
  });

  it('should bypass caching if no Idempotency-Key header is provided', async () => {
    reflector.getAllAndOverride.mockReturnValue(true);
    // Header is empty
    const result = await lastValueFrom(await interceptor.intercept(mockContext, mockCallHandler));

    expect(result).toEqual({ data: 'new response' });
    expect(cacheManager.get).not.toHaveBeenCalled();
    expect(cacheManager.set).not.toHaveBeenCalled();
  });

  it('should return cached response if it exists', async () => {
    reflector.getAllAndOverride.mockReturnValue(true);
    mockRequest.headers['idempotency-key'] = 'request-abc';
    
    cacheManager.get.mockResolvedValue({ data: 'cached response' });

    const result$ = await interceptor.intercept(mockContext, mockCallHandler);
    const result = await lastValueFrom(result$);

    expect(result).toEqual({ data: 'cached response' });
    expect(mockCallHandler.handle).not.toHaveBeenCalled();
  });

  it('should process request and cache response if cache is miss', async () => {
    reflector.getAllAndOverride.mockReturnValue(true);
    mockRequest.headers['idempotency-key'] = 'request-abc';
    
    cacheManager.get.mockResolvedValue(null); // Cache miss

    const result$ = await interceptor.intercept(mockContext, mockCallHandler);
    const result = await lastValueFrom(result$);

    expect(result).toEqual({ data: 'new response' });
    expect(cacheManager.set).toHaveBeenCalledWith(
      'idempotency:user-id:POST:/api/v1/bookings:request-abc',
      { data: 'new response' },
      24 * 60 * 60 * 1000 // 24 hours
    );
  });
});
