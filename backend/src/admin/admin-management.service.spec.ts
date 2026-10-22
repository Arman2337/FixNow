import { BadRequestException } from '@nestjs/common';
import type { Repository } from 'typeorm';
import { UserEntity } from '../users/user.entity';
import { UserRoleEntity } from '../users/user-role.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { ProviderVerificationEventEntity } from '../providers/verification/provider-verification-event.entity';
import { AdminManagementService } from './admin-management.service';
import type { ComplaintsService } from '../support/complaints/complaints.service';
import { ComplaintStatus } from '../../../shared/complaint-lifecycle.types';

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
  const complaints = {
    getComplaints: jest.fn(),
  } as unknown as ComplaintsService;
  const service = new AdminManagementService(
    users,
    roles,
    applications,
    profiles,
    events,
    complaints,
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

  it('filters complaint status and search in SQL before applying a later-page offset', async () => {
    const query = {
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([{ id: 'older-open-case' }]),
    };
    Object.assign(users, {
      manager: {
        getRepository: jest.fn(() => ({ createQueryBuilder: () => query })),
      },
    });
    await expect(
      service.listComplaints('admin', {
        limit: 21,
        offset: 20,
        status: ComplaintStatus.OPEN,
        search: 'leak',
      }),
    ).resolves.toEqual([{ id: 'older-open-case' }]);
    expect(query.andWhere).toHaveBeenCalledWith('complaint.status = :status', {
      status: ComplaintStatus.OPEN,
    });
    expect(query.andWhere).toHaveBeenCalledWith(
      expect.stringContaining('complaint.description ILIKE'),
      { search: '%leak%' },
    );
    expect(query.take).toHaveBeenCalledWith(21);
    expect(query.skip).toHaveBeenCalledWith(20);
    expect(query.addOrderBy).toHaveBeenCalledWith('complaint.id', 'DESC');
  });
});
