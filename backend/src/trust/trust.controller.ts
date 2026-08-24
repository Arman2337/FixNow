import { Controller, Get, Req } from '@nestjs/common';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { TrustService } from './trust.service';

/**
 * FN-111 provider-facing trust surface. The provider identity always comes
 * from the access token, so a provider can only ever read their own signal.
 */
@Controller('trust')
export class TrustController {
  constructor(private readonly trust: TrustService) {}

  @Get('my-accept-time')
  @RequirePermission(PERMISSIONS.trustAcceptTimeReadSelf)
  myAcceptTime(@Req() req: AuthorizedRequest) {
    return this.trust.providerAcceptTime(req.authorizationPrincipal!.userId);
  }
}
