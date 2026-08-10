import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../../auth/auth-audit-event.entity';
import { AuthSessionEntity } from '../../auth/auth-session.entity';
import { AccountStatus } from '../../users/account-status';
import { UserRoleEntity } from '../../users/user-role.entity';
import { UserEntity } from '../../users/user.entity';
import { AuthorizationPolicyService } from './authorization-policy.service';
import { AuthorizationService } from './authorization.service';
import { PERMISSIONS } from './permission-policies';

describe('AuthorizationService', () => {
  const verifyAsync = jest.fn();
  const findUser = jest.fn();
  const findSession = jest.fn();
  const findGrants = jest.fn();
  const saveAudit = jest.fn();
  const repositories = new Map<unknown, unknown>([
    [UserEntity, { findOneBy: findUser }],
    [AuthSessionEntity, { findOneBy: findSession }],
    [UserRoleEntity, { find: findGrants }],
    [AuthAuditEventEntity, { save: saveAudit }],
  ]);
  const dataSource = {
    getRepository: jest.fn((entity: unknown) => repositories.get(entity)),
  } as unknown as DataSource;
  const service = new AuthorizationService(
    dataSource,
    { verifyAsync } as unknown as JwtService,
    new AuthorizationPolicyService(),
  );

  beforeEach(() => {
    jest.clearAllMocks();
    verifyAsync.mockResolvedValue({
      sub: '00000000-0000-4000-8000-000000000001',
      sessionId: '00000000-0000-4000-8000-000000000002',
    });
    findUser.mockResolvedValue({
      id: '00000000-0000-4000-8000-000000000001',
      status: AccountStatus.Active,
    });
    findSession.mockResolvedValue({
      id: '00000000-0000-4000-8000-000000000002',
      userId: '00000000-0000-4000-8000-000000000001',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    findGrants.mockResolvedValue([{ role: { code: 'customer' } }]);
    saveAudit.mockResolvedValue(undefined);
  });

  it('uses authoritative database roles and records an allowed decision', async () => {
    await expect(
      service.authorizeAccessToken(
        'access-token',
        PERMISSIONS.bookingCreateSelf,
        {
          ownerId: '00000000-0000-4000-8000-000000000001',
        },
      ),
    ).resolves.toEqual({
      userId: '00000000-0000-4000-8000-000000000001',
      sessionId: '00000000-0000-4000-8000-000000000002',
      roles: ['customer'],
    });
    expect(saveAudit).toHaveBeenCalledWith({
      userId: '00000000-0000-4000-8000-000000000001',
      eventType: 'authorization.allowed',
      outcome: 'success',
    });
  });

  it('ignores a privileged token role when the database grant is customer', async () => {
    verifyAsync.mockResolvedValue({
      sub: '00000000-0000-4000-8000-000000000001',
      sessionId: '00000000-0000-4000-8000-000000000002',
      role: 'security_administrator',
    });
    await expect(
      service.authorizeAccessToken(
        'access-token',
        PERMISSIONS.roleGrantAuthorized,
        { targetPrincipalId: 'staff-1', independentApproval: true },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(saveAudit).toHaveBeenCalledWith({
      userId: '00000000-0000-4000-8000-000000000001',
      eventType: 'authorization.denied',
      outcome: 'denied',
    });
  });

  it('rejects a revoked authoritative session', async () => {
    findSession.mockResolvedValue({
      id: '00000000-0000-4000-8000-000000000002',
      userId: '00000000-0000-4000-8000-000000000001',
      revokedAt: new Date(),
      expiresAt: new Date(Date.now() + 60_000),
    });
    await expect(
      service.authorizeAccessToken(
        'access-token',
        PERMISSIONS.bookingCreateSelf,
        {
          ownerId: '00000000-0000-4000-8000-000000000001',
        },
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(saveAudit).toHaveBeenCalledWith({
      userId: '00000000-0000-4000-8000-000000000001',
      eventType: 'authorization.authentication',
      outcome: 'denied',
    });
  });

  it('audits a deleted token subject without violating the user foreign key', async () => {
    findUser.mockResolvedValue(null);
    await expect(
      service.authorizeAccessToken(
        'access-token',
        PERMISSIONS.bookingCreateSelf,
        { ownerId: '00000000-0000-4000-8000-000000000001' },
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(saveAudit).toHaveBeenCalledWith({
      userId: null,
      eventType: 'authorization.authentication',
      outcome: 'denied',
    });
  });
});
