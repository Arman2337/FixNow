import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { BookingReviewResponse } from '../../../shared/ratings.types';
import { CreateReviewDto } from './ratings.dto';
import { presentReview } from './ratings.presenter';
import { RatingsService } from './ratings.service';
import { ReviewPhotosService } from './review-photos.service';

interface UploadedPhoto {
  buffer: Buffer;
  mimetype: string;
}

@Controller('bookings')
export class RatingsController {
  constructor(
    private readonly ratings: RatingsService,
    private readonly photos: ReviewPhotosService,
  ) {}

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

  /** FN-110: attach a bounded photo to the booking's own review. */
  @Post(':id/review/photos')
  @UseInterceptors(
    FileInterceptor('photo', {
      limits: { files: 1, fileSize: 6 * 1024 * 1024 },
    }),
  )
  @RequireOwnPermission(PERMISSIONS.reviewCreateSelf)
  async attachPhoto(
    @Param('id') bookingId: string,
    @Req() request: AuthorizedRequest,
    @UploadedFile() file?: UploadedPhoto,
  ): Promise<{ photo: ReturnType<ReviewPhotosService['present']> }> {
    if (!file) {
      throw new BadRequestException('A review photo file is required');
    }
    const photo = await this.photos.attach(
      bookingId,
      request.authorizationPrincipal!.userId,
      file.mimetype,
      file.buffer,
    );
    return { photo: this.photos.present(photo) };
  }

  /** FN-110: participant photo view; non-authors see approved photos only. */
  @Get(':id/review/photos')
  @RequireOwnPermission(PERMISSIONS.reviewReadBooking)
  async listPhotos(
    @Param('id') bookingId: string,
    @Req() request: AuthorizedRequest,
  ) {
    const rows = await this.photos.listForParticipants(
      bookingId,
      request.authorizationPrincipal!.userId,
    );
    return { photos: rows.map((photo) => this.photos.present(photo)) };
  }
}
