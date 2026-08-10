import {
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthorizationGuard } from './authorization.guard';
import { AuthorizationService } from './authorization.service';
import { PERMISSIONS } from './permission-policies';

describe('AuthorizationGuard', () => {
  const request = { headers: {} };
  const context = {
    getHandler: jest.fn(),
    getClass: jest.fn(),
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  const reflector = { getAllAndOverride: jest.fn() };
  const authorization = {
    authorizeAccessToken: jest.fn(),
    auditPolicyMissing: jest.fn(),
  };
  const guard = new AuthorizationGuard(
    reflector as unknown as Reflector,
    authorization as unknown as AuthorizationService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    request.headers = {};
  });

  it('allows an explicitly public route', async () => {
    reflector.getAllAndOverride.mockReturnValueOnce(true);
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(authorization.authorizeAccessToken).not.toHaveBeenCalled();
  });

  it('denies a route that has no explicit policy classification', async () => {
    reflector.getAllAndOverride
      .mockReturnValueOnce(false)
      .mockReturnValueOnce(undefined);
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(authorization.auditPolicyMissing).toHaveBeenCalledTimes(1);
  });

  it('rejects malformed bearer authentication', async () => {
    reflector.getAllAndOverride
      .mockReturnValueOnce(false)
      .mockReturnValueOnce(PERMISSIONS.securityAuditReadAuthorized);
    request.headers = { authorization: 'Basic unsafe' };
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('delegates protected requests to authoritative authorization', async () => {
    reflector.getAllAndOverride
      .mockReturnValueOnce(false)
      .mockReturnValueOnce(PERMISSIONS.securityAuditReadAuthorized);
    request.headers = { authorization: 'Bearer header.payload.signature' };
    authorization.authorizeAccessToken.mockResolvedValue({
      userId: 'user-1',
      sessionId: 'session-1',
      roles: ['auditor'],
    });
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(authorization.authorizeAccessToken).toHaveBeenCalledWith(
      'header.payload.signature',
      PERMISSIONS.securityAuditReadAuthorized,
    );
  });
});
