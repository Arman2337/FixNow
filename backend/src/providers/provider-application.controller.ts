import { Controller, Get, Post, NotFoundException, BadRequestException, Request } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { ProviderApplicationEntity } from './provider-application.entity';
import { ProviderOnboardingStatus } from './provider-onboarding-status';
import { ProviderVerificationEventEntity } from './verification/provider-verification-event.entity';

@Controller('provider-applications')
export class ProviderApplicationController {
  constructor(
    @InjectRepository(ProviderApplicationEntity)
    private readonly applications: Repository<ProviderApplicationEntity>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  @Get('me')
  @RequireOwnPermission(PERMISSIONS.providerApplicationReadSelf)
  async getOwn(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderApplicationEntity> {
    const application = await this.applications.findOneBy({
      userId: request.authorizationPrincipal!.userId,
    });
    if (!application)
      throw new NotFoundException('Provider application not found');
    return application;
  }
  @Post('me/submit')
  @RequireOwnPermission(PERMISSIONS.providerApplicationUpdateSelf)
  async submitOwn(
    @Request() request: AuthorizedRequest,
  ): Promise<ProviderApplicationEntity> {
    const userId = request.authorizationPrincipal!.userId;
    
    return this.dataSource.transaction(async (manager) => {
      const application = await manager.findOneBy(ProviderApplicationEntity, { userId });
      if (!application) {
        throw new NotFoundException('Provider application not found');
      }
      
      if (
        application.status !== ProviderOnboardingStatus.Unverified &&
        application.status !== ProviderOnboardingStatus.ResubmissionRequested
      ) {
        throw new BadRequestException('Application cannot be submitted in its current state');
      }

      const from = application.status;
      application.status = ProviderOnboardingStatus.UnderReview;
      application.version += 1;
      const saved = await manager.save(ProviderApplicationEntity, application);

      await manager.save(ProviderVerificationEventEntity, manager.create(ProviderVerificationEventEntity, {
        applicationId: saved.id,
        actorUserId: userId,
        fromStatus: from,
        toStatus: ProviderOnboardingStatus.UnderReview,
        reason: 'provider-submitted',
        applicationVersion: saved.version,
      }));

      return saved;
    });
  }
}
