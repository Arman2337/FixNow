import { ExecutionContext } from '@nestjs/common';
import { firstValueFrom, of } from 'rxjs';
import { OwnershipProofInterceptor } from './ownership-proof.interceptor';
import type { AuthorizedRequest } from './authorization.guard';

describe('OwnershipProofInterceptor (SEC-002)', () => {
  const request = {} as AuthorizedRequest;
  const context = {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  const interceptor = new OwnershipProofInterceptor();

  const run = (handlerValue: unknown) =>
    firstValueFrom(
      interceptor.intercept(context, {
        handle: () => of(handlerValue),
      } as never),
    );

  beforeEach(() => {
    delete request.authorizationPrincipal;
  });

  it('passes a response whose principal owes nothing', async () => {
    request.authorizationPrincipal = {
      userId: 'u1',
      sessionId: 's1',
      roles: [],
    };
    await expect(run({ ok: true })).resolves.toEqual({ ok: true });
  });

  it('passes a response whose ownership was proven', async () => {
    request.authorizationPrincipal = {
      userId: 'u1',
      sessionId: 's1',
      roles: [],
      ownershipProven: true,
    };
    await expect(run({ ok: true })).resolves.toEqual({ ok: true });
  });

  it('rejects a response whose ownership obligation was never discharged', async () => {
    request.authorizationPrincipal = {
      userId: 'u1',
      sessionId: 's1',
      roles: [],
      ownershipProven: false,
    };
    await expect(run({ leaked: 'someone-elses-data' })).rejects.toThrow(
      'Access denied',
    );
  });
});
