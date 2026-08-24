import { Body, Controller, Param, Patch, Req } from '@nestjs/common';
import { IsIn, IsString } from 'class-validator';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { ModerateReviewDto } from './ratings.dto';
import { presentReview } from './ratings.presenter';
import { RatingsService } from './ratings.service';
import { ReviewPhotosService } from './review-photos.service';

class ModeratePhotoDto {
  @IsIn(['APPROVED', 'REJECTED']) status!: 'APPROVED' | 'REJECTED';
  @IsString() reason!: string;
}

@Controller('admin/reviews')
export class RatingsAdminController {
  constructor(
    private readonly ratings: RatingsService,
    private readonly photos: ReviewPhotosService,
  ) {}
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

  /** FN-110: permission-gated photo approve/reject with audit. */
  @Patch('photos/:photoId/moderation')
  @RequirePermission(PERMISSIONS.reviewModerate)
  async moderatePhoto(
    @Param('photoId') photoId: string,
    @Req() req: AuthorizedRequest,
    @Body() dto: ModeratePhotoDto,
  ) {
    const photo = await this.photos.moderate(
      photoId,
      req.authorizationPrincipal!.userId,
      dto.status,
      dto.reason,
    );
    return { photo: this.photos.present(photo) };
  }
}
