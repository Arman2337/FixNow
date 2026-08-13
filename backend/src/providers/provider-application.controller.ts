import { Controller, Get, NotFoundException, Request } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { ProviderApplicationEntity } from './provider-application.entity';

@Controller('provider-applications')
export class ProviderApplicationController {
  constructor(
    @InjectRepository(ProviderApplicationEntity)
    private readonly applications: Repository<ProviderApplicationEntity>,
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
}
