import { createHash, randomUUID } from 'crypto';
import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MALWARE_SCANNER } from '../../storage/malware-scanner';
import type { MalwareScanner } from '../../storage/malware-scanner';
import { PRIVATE_OBJECT_STORAGE } from '../../storage/private-object-storage';
import type { PrivateObjectStorage } from '../../storage/private-object-storage';
import { ProviderDocumentEntity } from './provider-document.entity';
import { ProviderDocumentAuditEntity } from './provider-document-audit.entity';
import { ProviderApplicationEntity } from '../provider-application.entity';

const MAX_BYTES = 10 * 1024 * 1024;
const TYPES = new Set(['identity', 'license', 'certification']);
const MIME = new Set(['application/pdf', 'image/jpeg', 'image/png']);

@Injectable()
export class ProviderDocumentService {
  constructor(
    @InjectRepository(ProviderDocumentEntity)
    private readonly documents: Repository<ProviderDocumentEntity>,
    @Inject(PRIVATE_OBJECT_STORAGE)
    private readonly storage: PrivateObjectStorage,
    @Inject(MALWARE_SCANNER) private readonly scanner: MalwareScanner,
    @InjectRepository(ProviderDocumentAuditEntity)
    private readonly audits: Repository<ProviderDocumentAuditEntity>,
    @InjectRepository(ProviderApplicationEntity)
    private readonly applications: Repository<ProviderApplicationEntity>,
  ) {}

  rejectMissingFile(): never {
    throw new BadRequestException('Document file is required');
  }

  async listOwn(userId: string): Promise<ProviderDocumentEntity[]> {
    return this.documents.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  async upload(
    userId: string,
    documentType: string,
    contentType: string,
    content: Buffer,
  ): Promise<ProviderDocumentEntity> {
    if (
      !TYPES.has(documentType) ||
      !MIME.has(contentType) ||
      content.length === 0 ||
      content.length > MAX_BYTES ||
      !this.matchesMagic(contentType, content)
    ) {
      throw new BadRequestException('Unsupported or invalid provider document');
    }
    const objectKey = `quarantine/${randomUUID()}`;
    await this.storage.putQuarantined(objectKey, content, contentType);
    const verdict = await this.scanner.scan(content);
    if (verdict !== 'clean') {
      await this.storage.delete(objectKey);
      throw new BadRequestException('Document failed security scanning');
    }
    const retentionDays = Number(
      process.env.PROVIDER_DOCUMENT_RETENTION_DAYS ?? '30',
    );
    if (
      !Number.isInteger(retentionDays) ||
      retentionDays < 1 ||
      retentionDays > 365
    ) {
      throw new Error(
        'PROVIDER_DOCUMENT_RETENTION_DAYS must be an integer from 1 to 365',
      );
    }
    const document = this.documents.create({
      userId,
      documentType,
      objectKey,
      contentType,
      sizeBytes: content.length,
      sha256: createHash('sha256').update(content).digest('hex'),
      status: 'available',
      retentionUntil: new Date(Date.now() + retentionDays * 86_400_000),
      deletedAt: null,
    });
    const saved = await this.documents.save(document);
    await this.audit(saved.id, userId, 'upload', 'allowed');
    return saved;
  }

  async read(
    userId: string,
    id: string,
  ): Promise<{ metadata: ProviderDocumentEntity; content: Buffer }> {
    const document = await this.find(id);
    await this.assertOwner(userId, document);
    if (document.status !== 'available')
      throw new NotFoundException('Provider document not found');
    await this.audit(document.id, userId, 'read', 'allowed');
    return {
      metadata: document,
      content: await this.storage.readPrivate(document.objectKey),
    };
  }

  async delete(userId: string, id: string): Promise<void> {
    const document = await this.find(id);
    await this.assertOwner(userId, document);
    if (document.status === 'deleted') return;
    await this.storage.delete(document.objectKey);
    document.status = 'deleted';
    document.deletedAt = new Date();
    await this.documents.save(document);
    await this.audit(document.id, userId, 'delete', 'allowed');
  }

  async listForReview(actorId: string, applicationId: string) {
    const application = await this.assertAssignedReview(actorId, applicationId);
    const documents = await this.documents.find({
      where: { userId: application.userId, status: 'available' },
      order: { createdAt: 'DESC' },
    });
    return documents.map(
      ({
        id,
        documentType,
        contentType,
        sizeBytes,
        status,
        retentionUntil,
        createdAt,
        updatedAt,
      }) => ({
        id,
        documentType,
        contentType,
        sizeBytes,
        status,
        retentionUntil,
        createdAt,
        updatedAt,
      }),
    );
  }

  async readForReview(
    actorId: string,
    applicationId: string,
    documentId: string,
  ) {
    const application = await this.assertAssignedReview(actorId, applicationId);
    const document = await this.find(documentId);
    if (
      document.userId !== application.userId ||
      document.status !== 'available'
    ) {
      await this.audit(document.id, actorId, 'review-read', 'denied');
      throw new NotFoundException('Provider document not found');
    }
    await this.audit(document.id, actorId, 'review-read', 'allowed');
    return {
      metadata: document,
      content: await this.storage.readPrivate(document.objectKey),
    };
  }

  private async assertAssignedReview(actorId: string, applicationId: string) {
    const application = await this.applications.findOneBy({
      id: applicationId,
    });
    if (!application || application.assignedReviewerUserId !== actorId) {
      throw new ForbiddenException(
        'Provider review is not assigned to this reviewer',
      );
    }
    return application;
  }

  private async find(id: string): Promise<ProviderDocumentEntity> {
    const document = await this.documents.findOne({ where: { id } });
    if (!document) throw new NotFoundException('Provider document not found');
    return document;
  }
  private async assertOwner(
    userId: string,
    document: ProviderDocumentEntity,
  ): Promise<void> {
    if (document.userId !== userId) {
      await this.audit(document.id, userId, 'access', 'denied');
      throw new ForbiddenException('Provider document access denied');
    }
  }
  private matchesMagic(type: string, value: Buffer): boolean {
    if (type === 'application/pdf')
      return value.subarray(0, 5).toString() === '%PDF-';
    if (type === 'image/png')
      return value
        .subarray(0, 8)
        .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    return (
      value.length >= 3 &&
      value[0] === 0xff &&
      value[1] === 0xd8 &&
      value[2] === 0xff
    );
  }
  private async audit(
    documentId: string,
    actorUserId: string,
    action: string,
    outcome: string,
  ): Promise<void> {
    await this.audits.save(
      this.audits.create({ documentId, actorUserId, action, outcome }),
    );
  }
}
