/* eslint-disable @typescript-eslint/unbound-method -- Jest assertions inspect mocks without invoking them. */
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthorizationGuard } from '../common/authorization/authorization.guard';
import { AuthorizationService } from '../common/authorization/authorization.service';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { IssueRecommendationController } from './issue-recommendation.controller';
import { IssueRecommendationService } from './issue-recommendation.service';

describe('IssueRecommendationController authorization boundary', () => {
  const recommendations = {
    recommend: jest.fn(),
  } as unknown as jest.Mocked<IssueRecommendationService>;
  const controller = new IssueRecommendationController(recommendations);
  const request = { headers: {} as Record<string, string> };
  const handler = Object.getOwnPropertyDescriptor(
    IssueRecommendationController.prototype,
    'recommend',
  )!.value as (this: void) => unknown;
  const context = {
    getHandler: () => handler,
    getClass: () => IssueRecommendationController,
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  const authorization = {
    authorizeAccessToken: jest.fn(),
    auditPolicyMissing: jest.fn(),
  } as unknown as jest.Mocked<AuthorizationService>;
  const guard = new AuthorizationGuard(new Reflector(), authorization);

  beforeEach(() => {
    jest.clearAllMocks();
    request.headers = {};
  });

  it('passes the authenticated customer identity to the advisory service', async () => {
    request.headers.authorization = 'Bearer customer-token';
    authorization.authorizeAccessToken.mockResolvedValue({
      userId: 'customer-1',
      sessionId: 'session-1',
      roles: ['customer'],
    });
    recommendations.recommend.mockResolvedValue({ kind: 'UNAVAILABLE' });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    await controller.recommend(request as never, {
      description: 'My sink is leaking',
    });

    expect(
      authorization.authorizeAccessToken as jest.Mock,
    ).toHaveBeenCalledWith(
      'customer-token',
      PERMISSIONS.aiRecommendationCreate,
      undefined,
      true,
    );
    expect(recommendations.recommend as jest.Mock).toHaveBeenCalledWith({
      userId: 'customer-1',
      description: 'My sink is leaking',
      clarificationContext: undefined,
    });
  });

  it.each([
    ['provider-token', ['verified_provider']],
    ['admin-token', ['operations_administrator']],
    ['inactive-token', ['customer']],
  ])('denies %s before the controller can invoke AI', async (token, roles) => {
    request.headers.authorization = `Bearer ${token}`;
    authorization.authorizeAccessToken.mockRejectedValue(
      new ForbiddenException(`Denied for ${roles.join(',')}`),
    );

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(recommendations.recommend as jest.Mock).not.toHaveBeenCalled();
  });
});
