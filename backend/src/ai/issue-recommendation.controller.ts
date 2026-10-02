import { Body, Controller, Post, Req } from '@nestjs/common';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { assertNoResourceToProve } from '../common/authorization/resource-ownership';
import { IssueRecommendationDto } from './issue-recommendation.dto';
import {
  IssueRecommendationResponse,
  IssueRecommendationService,
} from './issue-recommendation.service';

@Controller('ai/service-recommendation')
export class IssueRecommendationController {
  constructor(private readonly recommendations: IssueRecommendationService) {}

  @Post()
  @RequireOwnPermission(PERMISSIONS.aiRecommendationCreate)
  recommend(
    @Req() request: AuthorizedRequest,
    @Body() dto: IssueRecommendationDto,
  ): Promise<IssueRecommendationResponse> {
    // SEC-002: an advisory computed for the caller's own description. The
    // request body names no resource owned by anyone else, and the response is
    // a recommendation, not a stored record with an owner.
    assertNoResourceToProve(request.authorizationPrincipal);
    return this.recommendations.recommend({
      userId: request.authorizationPrincipal!.userId,
      description: dto.description,
      clarificationContext: dto.clarificationContext,
    });
  }
}
