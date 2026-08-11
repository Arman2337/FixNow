import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Request,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import { ProviderDocumentService } from './provider-document.service';

interface UploadedDocument {
  buffer: Buffer;
  mimetype: string;
}

@Controller('provider-documents')
export class ProviderDocumentController {
  constructor(private readonly service: ProviderDocumentService) {}
  @Post(':documentType')
  @RequireOwnPermission('provider.documents.create')
  @UseInterceptors(
    FileInterceptor('document', {
      limits: { files: 1, fileSize: 10 * 1024 * 1024 },
    }),
  )
  upload(
    @Request() request: AuthorizedRequest,
    @Param('documentType') type: string,
    @UploadedFile() file?: UploadedDocument,
  ) {
    if (!file) return this.service.rejectMissingFile();
    return this.service.upload(
      request.authorizationPrincipal!.userId,
      type,
      file.mimetype,
      file.buffer,
    );
  }
  @Get(':id')
  @RequireOwnPermission('provider.documents.read')
  async read(
    @Request() request: AuthorizedRequest,
    @Param('id') id: string,
    @Res() response: Response,
  ): Promise<void> {
    const result = await this.service.read(
      request.authorizationPrincipal!.userId,
      id,
    );
    response.setHeader('Content-Type', result.metadata.contentType);
    response.setHeader(
      'Content-Disposition',
      'attachment; filename="provider-document"',
    );
    response.setHeader('Cache-Control', 'no-store');
    response.send(result.content);
  }
  @Delete(':id')
  @RequireOwnPermission('provider.documents.delete')
  @HttpCode(HttpStatus.NO_CONTENT)
  delete(
    @Request() request: AuthorizedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    return this.service.delete(request.authorizationPrincipal!.userId, id);
  }
}
