import { ConflictException, ForbiddenException } from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { AccountStatus } from '../../users/account-status';
import { RoleEntity } from '../../users/role.entity';
import { UserEntity } from '../../users/user.entity';
import { ProviderApplicationEntity } from '../provider-application.entity';
import { ProviderOnboardingStatus } from '../provider-onboarding-status';
import { ProviderVerificationEventEntity } from './provider-verification-event.entity';
import { ProviderVerificationService } from './provider-verification.service';

describe('ProviderVerificationService', () => {
  const applications = { findOne: jest.fn(), save: jest.fn() };
  const events = { save: jest.fn() };
  const users = { findOne: jest.fn(), save: jest.fn() };
  const roles = { findOne: jest.fn() };
  const grants = {
    findOne: jest.fn(),
    create: jest.fn((value: Record<string, unknown>) => value),
    save: jest.fn(),
  };
  const manager = {
    getRepository: jest.fn((entity) =>
      entity === ProviderApplicationEntity
        ? applications
        : entity === ProviderVerificationEventEntity
          ? events
          : entity === UserEntity
            ? users
            : entity === RoleEntity
              ? roles
              : grants,
    ),
  } as unknown as EntityManager;
  const dataSource = {
    transaction: jest.fn((work: (value: EntityManager) => unknown) =>
      work(manager),
    ),
  } as unknown as DataSource;
  const service = new ProviderVerificationService(dataSource);
  const application = {
    id: 'app-id',
    userId: 'provider-id',
    status: ProviderOnboardingStatus.Unverified,
    assignedReviewerUserId: null,
    decisionReason: null,
    reviewedAt: null,
    version: 0,
  } as ProviderApplicationEntity;

  beforeEach(() => {
    jest.clearAllMocks();
    applications.findOne.mockResolvedValue({ ...application });
    applications.save.mockImplementation((v) => Promise.resolve(v));
    events.save.mockResolvedValue({});
    users.findOne.mockResolvedValue({
      id: 'provider-id',
      status: AccountStatus.PendingVerification,
    });
    roles.findOne.mockResolvedValue({
      id: 'role-id',
      code: 'verified_provider',
    });
    grants.findOne.mockResolvedValue(null);
    grants.save.mockResolvedValue({});
    users.save.mockResolvedValue({});
  });

  it('claims an unverified application and appends an event', async () => {
    const result = await service.claim('app-id', 'reviewer-id', 0);
    expect(result.status).toBe(ProviderOnboardingStatus.UnderReview);
    expect(result.assignedReviewerUserId).toBe('reviewer-id');
    expect(result.version).toBe(1);
    expect(events.save).toHaveBeenCalledWith(
      expect.objectContaining({
        fromStatus: 'unverified',
        toStatus: 'under_review',
      }),
    );
  });
  it('rejects a stale concurrent transition', async () => {
    await expect(service.claim('app-id', 'reviewer-id', 1)).rejects.toThrow(
      ConflictException,
    );
  });
  it('rejects self review', async () => {
    await expect(service.claim('app-id', 'provider-id', 0)).rejects.toThrow(
      ForbiddenException,
    );
  });
  it('requires a meaningful reason', () => {
    expect(() =>
      service.decide(
        'app-id',
        'reviewer-id',
        0,
        ProviderOnboardingStatus.Rejected,
        ' ',
      ),
    ).toThrow(ConflictException);
  });
  it('rejects an illegal transition', async () => {
    await expect(
      service.decide(
        'app-id',
        'reviewer-id',
        0,
        ProviderOnboardingStatus.Approved,
        'approved evidence',
      ),
    ).rejects.toThrow(ForbiddenException);
  });
  it('prevents an unassigned reviewer decision', async () => {
    applications.findOne.mockResolvedValue({
      ...application,
      status: ProviderOnboardingStatus.UnderReview,
      assignedReviewerUserId: 'other-id',
    });
    await expect(
      service.decide(
        'app-id',
        'reviewer-id',
        0,
        ProviderOnboardingStatus.Rejected,
        'invalid evidence',
      ),
    ).rejects.toThrow(ForbiddenException);
  });
  it.each([
    ProviderOnboardingStatus.Rejected,
    ProviderOnboardingStatus.ResubmissionRequested,
  ])('records the reason for %s', async (decision) => {
    applications.findOne.mockResolvedValue({
      ...application,
      status: ProviderOnboardingStatus.UnderReview,
      assignedReviewerUserId: 'reviewer-id',
    });
    const result = await service.decide(
      'app-id',
      'reviewer-id',
      0,
      decision,
      'document issue',
    );
    expect(result.decisionReason).toBe('document issue');
    expect(events.save).toHaveBeenCalled();
  });
  it('activates the account and grants verified-provider role only after approval', async () => {
    applications.findOne.mockResolvedValue({
      ...application,
      status: ProviderOnboardingStatus.UnderReview,
      assignedReviewerUserId: 'reviewer-id',
    });
    await service.decide(
      'app-id',
      'reviewer-id',
      0,
      ProviderOnboardingStatus.Approved,
      'requirements satisfied',
    );
    expect(users.save).toHaveBeenCalledWith(
      expect.objectContaining({ status: AccountStatus.Active }),
    );
    expect(grants.save).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'provider-id', roleId: 'role-id' }),
    );
  });
});
