/* eslint-disable @typescript-eslint/unbound-method -- Jest assertions inspect mocks without invoking them. */
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthorizationGuard } from '../../common/authorization/authorization.guard';
import { AuthorizationService } from '../../common/authorization/authorization.service';
import { PERMISSIONS } from '../../common/authorization/permission-policies';
import { ProblemClassificationController } from './problem-classification.controller';
import { ProblemClassificationService } from './problem-classification.service';

describe('ProblemClassificationController authorization boundary', () => {
  const analysis = {
    analyzeImage: jest.fn(),
    analyzeVoice: jest.fn(),
    analyzeCombined: jest.fn(),
  } as unknown as jest.Mocked<ProblemClassificationService>;
  const controller = new ProblemClassificationController(analysis);
  const request = { headers: {} as Record<string, string> };
  const handler = Object.getOwnPropertyDescriptor(
    ProblemClassificationController.prototype,
    'analyzeImage',
  )!.value as (this: void) => unknown;
  const context = {
    getHandler: () => handler,
    getClass: () => ProblemClassificationController,
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

  it('passes the authenticated customer identity to the analysis service', async () => {
    request.headers.authorization = 'Bearer customer-token';
    authorization.authorizeAccessToken.mockResolvedValue({
      userId: 'customer-1',
      sessionId: 'session-1',
      roles: ['customer'],
    });
    analysis.analyzeImage.mockResolvedValue({
      kind: 'unavailable',
      source: 'image',
      errorCode: 'AI_DISABLED',
    });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    await controller.analyzeImage(request as never, {
      buffer: Buffer.from([0xff, 0xd8, 0xff]),
      mimetype: 'image/jpeg',
    });

    // The guard enforces the customer-scoped permission with own-resource=true.
    expect(
      authorization.authorizeAccessToken as jest.Mock,
    ).toHaveBeenCalledWith(
      'customer-token',
      PERMISSIONS.aiProblemAnalysisCreate,
      undefined,
      true,
    );
    expect(analysis.analyzeImage as jest.Mock).toHaveBeenCalledWith({
      userId: 'customer-1',
      image: { bytes: Buffer.from([0xff, 0xd8, 0xff]), mimeType: 'image/jpeg' },
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
    expect(analysis.analyzeImage as jest.Mock).not.toHaveBeenCalled();
  });

  it('returns a clean INPUT_REJECTED fallback when no image is uploaded', async () => {
    const result = await controller.analyzeImage(request as never, undefined);

    expect(result).toEqual({
      kind: 'unavailable',
      source: 'image',
      errorCode: 'INPUT_REJECTED',
    });
    expect(analysis.analyzeImage as jest.Mock).not.toHaveBeenCalled();
  });
});
