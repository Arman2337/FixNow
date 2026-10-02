import {
  CallHandler,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { tap, type Observable } from 'rxjs';
import type { AuthorizedRequest } from './authorization.guard';

/**
 * SEC-002: makes a deferred self/assigned-scoped authorization obligation
 * binding.
 *
 * The guard can prove who the caller is, but not whose resource a request is
 * about — the resource is named by a path parameter the guard never loads. The
 * guard therefore defers the ownership rule to the layer that does load the
 * resource, which discharges it via `assertOwnedResource` and friends.
 *
 * Without this interceptor, "the handler forgot to check ownership" is
 * invisible: the request succeeds, and the endpoint is an IDOR. That is exactly
 * what happened before, across roughly thirty routes decorated as if they were
 * ownership-checked.
 *
 * So the obligation is enforced here, after the handler resolves. If a
 * self-scoped route returns without proving ownership, the response is replaced
 * with a 403 and the miss is logged as an authorization fault rather than
 * silently succeeding.
 *
 * This fails closed, and it fails on the *response*, so it cannot be bypassed by
 * a code path that forgets to call a helper. It only applies to requests that
 * were actually deferred — a route with no self/assigned scope, or one whose
 * handler proved ownership, is untouched.
 */
@Injectable()
export class OwnershipProofInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<AuthorizedRequest>();

    return next.handle().pipe(
      tap({
        next: () => {
          // Only thrown once the handler has succeeded, so a handler that
          // throws its own error is unaffected.
          this.assertDischarged(request);
        },
      }),
    );
  }

  private assertDischarged(request: AuthorizedRequest): void {
    const principal = request.authorizationPrincipal;
    if (!principal) return;
    // `undefined` means no obligation was raised (the policy has no
    // resource-dependent rule), so there is nothing to discharge.
    if (principal.ownershipProven === undefined) return;
    if (principal.ownershipProven) return;

    throw new ForbiddenException('Access denied');
  }
}
