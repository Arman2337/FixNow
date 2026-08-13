import { BadRequestException } from '@nestjs/common';
import type { Repository } from 'typeorm';
import { UserEntity } from '../users/user.entity';
import { UserRoleEntity } from '../users/user-role.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { ProviderVerificationEventEntity } from '../providers/verification/provider-verification-event.entity';
import { AdminManagementService } from './admin-management.service';

describe('AdminManagementService', () => {
  const users = { findOneBy: jest.fn() } as unknown as Repository<UserEntity>;
  const roles = { find: jest.fn() } as unknown as Repository<UserRoleEntity>;
  const applications = {
    findOneBy: jest.fn(),
  } as unknown as Repository<ProviderApplicationEntity>;
  const profiles = {
    findOneBy: jest.fn(),
  } as unknown as Repository<ProviderProfileEntity>;
  const events = {
    find: jest.fn(),
  } as unknown as Repository<ProviderVerificationEventEntity>;
  const service = new AdminManagementService(
    users,
    roles,
    applications,
    profiles,
    events,
  );

  beforeEach(() => jest.clearAllMocks());

  it('returns a minimized user detail without identity or credential data', async () => {
    (users.findOneBy as jest.Mock).mockResolvedValue({
      id: 'user-id',
      status: 'active',
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
      statusReason: 'not projected',
    });
    (roles.find as jest.Mock).mockResolvedValue([
      { role: { code: 'support_agent' } },
    ]);
    await expect(service.userDetail('user-id')).resolves.toEqual({
      id: 'user-id',
      status: 'active',
      roles: ['support_agent'],
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
    });
  });

  it('redacts provider coordinates while retaining immutable audit attribution', async () => {
    (applications.findOneBy as jest.Mock).mockResolvedValue({
      id: 'application-id',
      userId: 'provider-id',
      status: 'under_review',
      assignedReviewerUserId: 'reviewer-id',
      decisionReason: null,
      reviewedAt: null,
      version: 2,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
    });
    (profiles.findOneBy as jest.Mock).mockResolvedValue({
      displayName: 'Provider',
      bio: 'Qualified professional',
      serviceRadiusKm: 10,
      baseLatitude: 12.34,
      baseLongitude: 56.78,
    });
    (events.find as jest.Mock).mockResolvedValue([
      {
        id: 'event-id',
        actorUserId: 'reviewer-id',
        fromStatus: 'unverified',
        toStatus: 'under_review',
        reason: 'review-claimed',
        applicationVersion: 2,
        createdAt: new Date('2026-01-02'),
      },
    ]);
    const result = await service.applicationDetail('application-id');
    expect(result.profile).toEqual({
      displayName: 'Provider',
      bio: 'Qualified professional',
      serviceRadiusKm: 10,
    });
    expect(result.profile).not.toHaveProperty('baseLatitude');
    expect(result.events).toEqual([
      expect.objectContaining({
        actorUserId: 'reviewer-id',
        applicationVersion: 2,
      }),
    ]);
  });

  it('rejects malformed pagination cursors before querying', async () => {
    await expect(
      service.listUsers({ limit: 20, cursor: 'not-a-cursor' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
