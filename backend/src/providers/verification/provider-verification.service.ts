import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { AccountStatus } from '../../users/account-status';
import { RoleEntity } from '../../users/role.entity';
import { UserRoleEntity } from '../../users/user-role.entity';
import { UserEntity } from '../../users/user.entity';
import { ProviderApplicationEntity } from '../provider-application.entity';
import { ProviderOnboardingStatus } from '../provider-onboarding-status';
import { ProviderVerificationEventEntity } from './provider-verification-event.entity';

@Injectable()
export class ProviderVerificationService {
  constructor(private readonly dataSource: DataSource) {}

  claim(
    applicationId: string,
    reviewerId: string,
    expectedVersion: number,
  ): Promise<ProviderApplicationEntity> {
    return this.transition(
      applicationId,
      reviewerId,
      expectedVersion,
      ProviderOnboardingStatus.UnderReview,
      'review-claimed',
      false,
    );
  }

  decide(
    applicationId: string,
    reviewerId: string,
    expectedVersion: number,
    decision: ProviderOnboardingStatus,
    reason: string,
  ): Promise<ProviderApplicationEntity> {
    if (
      ![
        ProviderOnboardingStatus.Approved,
        ProviderOnboardingStatus.Rejected,
        ProviderOnboardingStatus.ResubmissionRequested,
      ].includes(decision)
    )
      throw new ConflictException('Illegal verification decision');
    const normalizedReason = reason.trim();
    if (normalizedReason.length < 3)
      throw new ConflictException('Verification reason is required');
    return this.transition(
      applicationId,
      reviewerId,
      expectedVersion,
      decision,
      normalizedReason,
      true,
    );
  }

  private async transition(
    applicationId: string,
    actorId: string,
    expectedVersion: number,
    to: ProviderOnboardingStatus,
    reason: string,
    requireAssignment: boolean,
  ): Promise<ProviderApplicationEntity> {
    return this.dataSource.transaction(async (manager) => {
      const repository = manager.getRepository(ProviderApplicationEntity);
      const application = await repository.findOne({
        where: { id: applicationId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!application)
        throw new NotFoundException('Provider application not found');
      if (application.userId === actorId)
        throw new ForbiddenException(
          'Providers cannot review their own application',
        );
      if (application.version !== expectedVersion)
        throw new ConflictException('Provider application changed');
      if (requireAssignment && application.assignedReviewerUserId !== actorId)
        throw new ForbiddenException('Review is not assigned to this reviewer');
      if (!this.allowed(application.status, to))
        throw new ConflictException('Illegal provider verification transition');
      const from = application.status;
      application.status = to;
      application.version += 1;
      application.decisionReason = reason;
      if (to === ProviderOnboardingStatus.UnderReview)
        application.assignedReviewerUserId = actorId;
      if (requireAssignment) application.reviewedAt = new Date();
      const saved = await repository.save(application);
      await manager.getRepository(ProviderVerificationEventEntity).save({
        applicationId,
        actorUserId: actorId,
        fromStatus: from,
        toStatus: to,
        reason,
        applicationVersion: saved.version,
      });
      if (to === ProviderOnboardingStatus.Approved)
        await this.activateProvider(manager, application.userId, actorId);
      return saved;
    });
  }

  private allowed(
    from: ProviderOnboardingStatus,
    to: ProviderOnboardingStatus,
  ): boolean {
    return (
      (from === ProviderOnboardingStatus.Unverified &&
        to === ProviderOnboardingStatus.UnderReview) ||
      (from === ProviderOnboardingStatus.UnderReview &&
        [
          ProviderOnboardingStatus.Approved,
          ProviderOnboardingStatus.Rejected,
          ProviderOnboardingStatus.ResubmissionRequested,
        ].includes(to))
    );
  }

  private async activateProvider(
    manager: EntityManager,
    userId: string,
    actorId: string,
  ): Promise<void> {
    const user = await manager
      .getRepository(UserEntity)
      .findOne({ where: { id: userId }, lock: { mode: 'pessimistic_write' } });
    const role = await manager
      .getRepository(RoleEntity)
      .findOne({ where: { code: 'verified_provider' } });
    if (!user || !role)
      throw new ConflictException('Provider activation prerequisites missing');
    user.status = AccountStatus.Active;
    user.statusReason = 'provider-approved';
    user.statusChangedAt = new Date();
    await manager.getRepository(UserEntity).save(user);
    const grants = manager.getRepository(UserRoleEntity);
    if (!(await grants.findOne({ where: { userId, roleId: role.id } })))
      await grants.save(
        grants.create({
          userId,
          roleId: role.id,
          assignedByUserId: actorId,
          reason: 'provider-approved',
          expiresAt: null,
        }),
      );
  }
}
