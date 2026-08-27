import {
  Body,
  Controller,
  Post,
  Req,
  UploadedFile,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import {
  FileFieldsInterceptor,
  FileInterceptor,
} from '@nestjs/platform-express';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../../common/authorization/permission-policies';
import {
  ProblemAnalysisResult,
  ProblemAnalysisSource,
} from '../../../../shared/problem-analysis.types';
import { ProblemAnalysisMediaDto } from './problem-classification.dto';
import { ProblemClassificationService } from './problem-classification.service';

interface UploadedMedia {
  readonly buffer: Buffer;
  readonly mimetype: string;
}

/**
 * Hard multipart ceilings for memory safety only. They match the env `@Max`
 * bounds and sit ABOVE the per-request configured caps (`AI_MAX_IMAGE_BYTES` /
 * `AI_MAX_AUDIO_BYTES`), so ordinary oversized uploads are rejected cleanly by
 * the service as `INPUT_REJECTED` rather than as a transport error.
 */
const MAX_IMAGE_UPLOAD_BYTES = 33_554_432; // 32 MiB
const MAX_AUDIO_UPLOAD_BYTES = 52_428_800; // 50 MiB

/**
 * Advisory multimodal problem-analysis endpoints (FN-058 voice, FN-059 image).
 *
 * Customer-only, and governed: the underlying pipeline is disabled by default
 * and blocked from production until the ADR-0014 release gate passes. Missing
 * or unusable uploads return the same clean `unavailable` shape the AI layer
 * uses, so the client always falls back to manual selection — never a 500.
 */
@Controller('ai/problem-analysis')
export class ProblemClassificationController {
  constructor(private readonly analysis: ProblemClassificationService) {}

  @Post('image')
  @RequireOwnPermission(PERMISSIONS.aiProblemAnalysisCreate)
  @UseInterceptors(
    FileInterceptor('image', {
      limits: { files: 1, fileSize: MAX_IMAGE_UPLOAD_BYTES },
    }),
  )
  analyzeImage(
    @Req() request: AuthorizedRequest,
    @UploadedFile() image?: UploadedMedia,
  ): Promise<ProblemAnalysisResult> {
    if (!image) return rejected('image');
    return this.analysis.analyzeImage({
      userId: request.authorizationPrincipal!.userId,
      image: { bytes: image.buffer, mimeType: image.mimetype },
    });
  }

  @Post('voice')
  @RequireOwnPermission(PERMISSIONS.aiProblemAnalysisCreate)
  @UseInterceptors(
    FileInterceptor('audio', {
      limits: { files: 1, fileSize: MAX_AUDIO_UPLOAD_BYTES },
    }),
  )
  analyzeVoice(
    @Req() request: AuthorizedRequest,
    @Body() dto: ProblemAnalysisMediaDto,
    @UploadedFile() audio?: UploadedMedia,
  ): Promise<ProblemAnalysisResult> {
    if (!audio) return rejected('voice');
    return this.analysis.analyzeVoice({
      userId: request.authorizationPrincipal!.userId,
      audio: { bytes: audio.buffer, mimeType: audio.mimetype },
      ...(dto.languageHint ? { languageHint: dto.languageHint } : {}),
    });
  }

  @Post('combined')
  @RequireOwnPermission(PERMISSIONS.aiProblemAnalysisCreate)
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'image', maxCount: 1 },
        { name: 'audio', maxCount: 1 },
      ],
      { limits: { files: 2, fileSize: MAX_AUDIO_UPLOAD_BYTES } },
    ),
  )
  analyzeCombined(
    @Req() request: AuthorizedRequest,
    @Body() dto: ProblemAnalysisMediaDto,
    @UploadedFiles()
    files?: { image?: UploadedMedia[]; audio?: UploadedMedia[] },
  ): Promise<ProblemAnalysisResult> {
    const image = files?.image?.[0];
    const audio = files?.audio?.[0];
    if (!image || !audio) return rejected('image_voice');
    return this.analysis.analyzeCombined({
      userId: request.authorizationPrincipal!.userId,
      image: { bytes: image.buffer, mimeType: image.mimetype },
      audio: { bytes: audio.buffer, mimeType: audio.mimetype },
      ...(dto.languageHint ? { languageHint: dto.languageHint } : {}),
    });
  }
}

function rejected(
  source: ProblemAnalysisSource,
): Promise<ProblemAnalysisResult> {
  return Promise.resolve({
    kind: 'unavailable',
    source,
    errorCode: 'INPUT_REJECTED',
  });
}
