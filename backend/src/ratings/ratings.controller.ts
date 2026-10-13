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
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
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
    const principal = request.authorizationPrincipal!;
    // SEC-002: `presentReview` strips both party columns, so the service
    // discharges against the booking it proved the caller owns.
    const review = await this.ratings.createForCompletedBooking(
      bookingId,
      principal.userId,
      dto,
      principal,
    );
    return { review: presentReview(review), providerRating: null };
  }

  @Get(':id/review')
  @RequireOwnPermission(PERMISSIONS.reviewReadBooking)
  async get(
    @Param('id') bookingId: string,
    @Req() request: AuthorizedRequest,
  ): Promise<BookingReviewResponse> {
    const principal = request.authorizationPrincipal!;
    const actorId = principal.userId;
    // SEC-002: either party to the booking may read the review; the answer may
    // be `null`, so the service discharges on the booking.
    const review = await this.ratings.getForBooking(
      bookingId,
      actorId,
      principal,
    );
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
      // SEC-002: the projected photo carries no owner, so the service compares
      // the review's `customerId` against the principal.
      request.authorizationPrincipal,
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
      // SEC-002: party membership is proved and discharged in the service.
      request.authorizationPrincipal,
    );
    return { photos: rows.map((photo) => this.photos.present(photo)) };
  }

  /**
   * FN-144. The image bytes for a photo this caller is allowed to see.
   *
   * `inline` because the consumer is a thumbnail in the app; `nosniff` plus the
   * stored content type stop a rejected upload being re-interpreted as
   * something executable, and `no-store` keeps a customer's review out of shared
   * caches.
   */
  @Get(':id/review/photos/:photoId/content')
  @RequireOwnPermission(PERMISSIONS.reviewReadBooking)
  async photoContent(
    @Req() request: AuthorizedRequest,
    @Res() response: Response,
    @Param('id') bookingId: string,
    @Param('photoId') photoId: string,
  ): Promise<void> {
    const principal = request.authorizationPrincipal!;
    const result = await this.photos.readPhoto(
      bookingId,
      photoId,
      principal.userId,
      principal,
    );
    response.setHeader('Content-Type', result.metadata.contentType);
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Disposition', 'inline');
    response.setHeader('Cache-Control', 'no-store, private');
    response.send(result.content);
  }
}
