import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { IsIn, IsString } from 'class-validator';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  isJobProofStage,
  JobProofPhotosService,
} from './job-proof-photos.service';
import { JobProofStage } from './domain/job-proof-photo.entity';

interface UploadedProofPhoto {
  mimetype?: string;
  buffer?: Buffer;
}

/**
 * FN-142. The `stage` field is validated by the DTO and then re-checked by the
 * service. Two checks is the point: the DTO rejects it at the edge with a 400
 * naming the allowed values, and the service does not trust a caller that
 * skipped the DTO.
 */
export class CaptureJobProofDto {
  @IsString()
  @IsIn([JobProofStage.BEFORE, JobProofStage.AFTER])
  stage!: string;
}

@Controller('bookings/:id/job-proof/photos')
export class JobProofPhotosController {
  constructor(private readonly proofs: JobProofPhotosService) {}

  /** Capture the before or after shot. Provider only. */
  @Post()
  @UseInterceptors(
    FileInterceptor('photo', {
      limits: { files: 1, fileSize: 6 * 1024 * 1024 },
    }),
  )
  @RequireOwnPermission(PERMISSIONS.jobProofCreateSelf)
  async capture(
    @Req() request: AuthorizedRequest,
    @Param('id') bookingId: string,
    @Body() dto: CaptureJobProofDto,
    @UploadedFile() file?: UploadedProofPhoto,
  ): Promise<{ photo: ReturnType<JobProofPhotosService['present']> }> {
    const principal = request.authorizationPrincipal!;
    if (!file?.buffer) {
      throw new BadRequestException('A job proof photo file is required');
    }
    if (!isJobProofStage(dto.stage)) {
      throw new BadRequestException(
        'A job proof stage must be BEFORE or AFTER',
      );
    }
    const photo = await this.proofs.capture({
      bookingId,
      providerId: principal.userId,
      stage: dto.stage,
      contentType: file.mimetype ?? '',
      content: file.buffer,
      principal,
    });
    return { photo: this.proofs.present(photo) };
  }

  /** Participant view of the before/after pair. */
  @Get()
  @RequireOwnPermission(PERMISSIONS.jobProofReadBooking)
  async list(
    @Req() request: AuthorizedRequest,
    @Param('id') bookingId: string,
  ) {
    const principal = request.authorizationPrincipal!;
    const rows = await this.proofs.listForParticipants(
      bookingId,
      principal.userId,
      principal,
    );
    return { photos: rows.map((photo) => this.proofs.present(photo)) };
  }

  /**
   * The image bytes.
   *
   * `inline` rather than `attachment` because the consumer is a slider in the
   * app, not a download; `nosniff` plus a fixed content type stop a stored file
   * being re-interpreted as something executable, and `no-store` keeps a
   * customer's proof out of shared caches.
   */
  @Get(':photoId/content')
  @RequireOwnPermission(PERMISSIONS.jobProofReadBooking)
  async content(
    @Req() request: AuthorizedRequest,
    @Res() response: Response,
    @Param('id') bookingId: string,
    @Param('photoId') photoId: string,
  ): Promise<void> {
    const principal = request.authorizationPrincipal!;
    const result = await this.proofs.readPhoto(
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
