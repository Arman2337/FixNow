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
import {
  assertOwnedCollection,
  assertOwnedResource,
} from '../../common/authorization/resource-ownership';
import { ProviderDocumentService } from './provider-document.service';

interface UploadedDocument {
  buffer: Buffer;
  mimetype: string;
}

@Controller('provider-documents')
export class ProviderDocumentController {
  constructor(private readonly service: ProviderDocumentService) {}
  @Get()
  @RequireOwnPermission('provider.documents.read')
  async list(@Request() request: AuthorizedRequest) {
    const principal = request.authorizationPrincipal!;
    const documents = await this.service.listOwn(principal.userId);
    // SEC-002: scoped by `where: { userId }`; prove it against the rows read.
    assertOwnedCollection(principal, documents, 'userId');
    return {
      documents: documents.map((document) => ({
        id: document.id,
        documentType: document.documentType,
        contentType: document.contentType,
        sizeBytes: document.sizeBytes,
        status: document.status,
        retentionUntil: document.retentionUntil,
        createdAt: document.createdAt,
        updatedAt: document.updatedAt,
      })),
    };
  }
  @Post(':documentType')
  @RequireOwnPermission('provider.documents.create')
  @UseInterceptors(
    FileInterceptor('document', {
      limits: { files: 1, fileSize: 10 * 1024 * 1024 },
    }),
  )
  async upload(
    @Request() request: AuthorizedRequest,
    @Param('documentType') type: string,
    @UploadedFile() file?: UploadedDocument,
  ) {
    if (!file) return this.service.rejectMissingFile();
    const principal = request.authorizationPrincipal!;
    const document = await this.service.upload(
      principal.userId,
      type,
      file.mimetype,
      file.buffer,
    );
    assertOwnedResource(principal, document.userId, 'providerDocument.userId');
    return document;
  }
  @Get(':id')
  @RequireOwnPermission('provider.documents.read')
  async read(
    @Request() request: AuthorizedRequest,
    @Param('id') id: string,
    @Res() response: Response,
  ): Promise<void> {
    const principal = request.authorizationPrincipal!;
    const result = await this.service.read(principal.userId, id);
    // `read` already refuses a foreign document; this compares the stored
    // document's real owner against the principal before any bytes are served.
    assertOwnedResource(
      principal,
      result.metadata.userId,
      'providerDocument.userId',
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
    // `delete` returns nothing, so the obligation is discharged inside the
    // service, next to the ownership check that already guards the write.
    return this.service.delete(
      request.authorizationPrincipal!.userId,
      id,
      request.authorizationPrincipal,
    );
  }
}
