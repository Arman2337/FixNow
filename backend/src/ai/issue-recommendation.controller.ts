import { Body, Controller, Post, Req } from '@nestjs/common';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
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
    return this.recommendations.recommend({
      userId: request.authorizationPrincipal!.userId,
      description: dto.description,
      clarificationContext: dto.clarificationContext,
    });
  }
}
