import { Body, Controller, Param, Post, Request } from '@nestjs/common';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { RequirePermission } from '../../common/authorization/authorization.decorators';
import { ProviderApplicationEntity } from '../provider-application.entity';
import {
  ClaimProviderApplicationDto,
  ProviderVerificationDecisionDto,
} from './provider-verification.dto';
import { ProviderVerificationService } from './provider-verification.service';

@Controller('provider-verification')
export class ProviderVerificationController {
  constructor(private readonly service: ProviderVerificationService) {}
  @Post(':applicationId/claim')
  @RequirePermission('providers.verification.review')
  claim(
    @Request() request: AuthorizedRequest,
    @Param('applicationId') id: string,
    @Body() input: ClaimProviderApplicationDto,
  ): Promise<ProviderApplicationEntity> {
    return this.service.claim(
      id,
      request.authorizationPrincipal!.userId,
      input.expectedVersion,
    );
  }
  @Post(':applicationId/decision')
  @RequirePermission('providers.verification.review')
  decide(
    @Request() request: AuthorizedRequest,
    @Param('applicationId') id: string,
    @Body() input: ProviderVerificationDecisionDto,
  ): Promise<ProviderApplicationEntity> {
    return this.service.decide(
      id,
      request.authorizationPrincipal!.userId,
      input.expectedVersion,
      input.decision,
      input.reason,
    );
  }
}
