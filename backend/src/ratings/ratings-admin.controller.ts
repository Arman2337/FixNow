import { Body, Controller, Param, Patch, Req } from '@nestjs/common';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { ModerateReviewDto } from './ratings.dto';
import { presentReview } from './ratings.presenter';
import { RatingsService } from './ratings.service';

@Controller('admin/reviews')
export class RatingsAdminController {
  constructor(private readonly ratings: RatingsService) {}
  @Patch(':id/moderation')
  @RequirePermission(PERMISSIONS.reviewModerate)
  async moderate(
    @Param('id') id: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: ModerateReviewDto,
  ) {
    return {
      review: presentReview(
        await this.ratings.moderate(
          id,
          req.authorizationPrincipal!.userId,
          dto.moderationStatus,
          dto.reason,
        ),
      ),
    };
  }
}
