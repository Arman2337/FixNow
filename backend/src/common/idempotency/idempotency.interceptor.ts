import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Inject,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { Observable, of } from 'rxjs';
import { tap } from 'rxjs/operators';
import { IDEMPOTENT_KEY } from './idempotency.decorator';
import { AuthorizedRequest } from '../authorization/authorization.guard';

/**
 * IdempotencyInterceptor intercepts incoming requests that contain an `Idempotency-Key` header.
 * It caches the successful response in Redis. If a customer retries the same request,
 * the interceptor will short-circuit and return the cached response.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  // Store responses for 24 hours (in milliseconds)
  private readonly TTL = 24 * 60 * 60 * 1000;

  constructor(
    private readonly reflector: Reflector,
    @Inject(CACHE_MANAGER) private readonly cacheManager: Cache,
  ) {}

  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<any>> {
    const isIdempotent = this.reflector.getAllAndOverride<boolean>(
      IDEMPOTENT_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!isIdempotent) {
      return next.handle();
    }

    const request = context.switchToHttp().getRequest<AuthorizedRequest>();
    const idempotencyKey = request.headers['idempotency-key'];

    if (!idempotencyKey || typeof idempotencyKey !== 'string') {
      // If no idempotency key is provided, just process the request normally
      return next.handle();
    }

    const userId = request.authorizationPrincipal?.userId;
    const method = request.method;
    const path = request.path;

    // The cache key incorporates the user, endpoint, and their idempotency key
    // to prevent cross-user or cross-endpoint collisions.
    const cacheKey = `idempotency:${userId}:${method}:${path}:${idempotencyKey}`;

    const cachedResponse = await this.cacheManager.get(cacheKey);

    if (cachedResponse) {
      // Short-circuit and return the cached response
      return of(cachedResponse);
    }

    return next.handle().pipe(
      tap(async (response) => {
        // Cache the successful response
        await this.cacheManager.set(cacheKey, response, this.TTL);
      }),
    );
  }
}
