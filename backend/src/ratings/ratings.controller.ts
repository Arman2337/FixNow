import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { BookingReviewResponse } from '../../../shared/ratings.types';
import { CreateReviewDto } from './ratings.dto';
import { presentReview } from './ratings.presenter';
import { RatingsService } from './ratings.service';

@Controller('bookings')
export class RatingsController {
  constructor(private readonly ratings: RatingsService) {}

  @Post(':id/review')
  @HttpCode(HttpStatus.CREATED)
  @RequireOwnPermission(PERMISSIONS.reviewCreateSelf)
  async create(
    @Param('id') bookingId: string,
    @Req() request: AuthorizedRequest,
    @Body() dto: CreateReviewDto,
  ): Promise<BookingReviewResponse> {
    const review = await this.ratings.createForCompletedBooking(
      bookingId,
      request.authorizationPrincipal!.userId,
      dto,
    );
    return { review: presentReview(review), providerRating: null };
  }

  @Get(':id/review')
  @RequireOwnPermission(PERMISSIONS.reviewReadBooking)
  async get(
    @Param('id') bookingId: string,
    @Req() request: AuthorizedRequest,
  ): Promise<BookingReviewResponse> {
    const actorId = request.authorizationPrincipal!.userId;
    const review = await this.ratings.getForBooking(bookingId, actorId);
    return {
      review: review ? presentReview(review) : null,
      providerRating:
        review?.providerId === actorId
          ? await this.ratings.providerRatingFor(actorId)
          : null,
    };
  }
}
