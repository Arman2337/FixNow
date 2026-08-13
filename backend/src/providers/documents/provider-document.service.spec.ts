/* eslint-disable @typescript-eslint/unbound-method */
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MALWARE_SCANNER, MalwareScanner } from '../../storage/malware-scanner';
import {
  PRIVATE_OBJECT_STORAGE,
  PrivateObjectStorage,
} from '../../storage/private-object-storage';
import { ProviderDocumentAuditEntity } from './provider-document-audit.entity';
import { ProviderDocumentEntity } from './provider-document.entity';
import { ProviderDocumentService } from './provider-document.service';

describe('ProviderDocumentService', () => {
  let service: ProviderDocumentService;
  let documents: jest.Mocked<Repository<ProviderDocumentEntity>>;
  let audits: jest.Mocked<Repository<ProviderDocumentAuditEntity>>;
  let storage: jest.Mocked<PrivateObjectStorage>;
  let scanner: jest.Mocked<MalwareScanner>;
  const pdf = Buffer.from('%PDF-safe');
  const entity = {
    id: 'doc-id',
    userId: 'user-id',
    documentType: 'identity',
    objectKey: 'quarantine/key',
    contentType: 'application/pdf',
    sizeBytes: 9,
    sha256: 'a'.repeat(64),
    status: 'available',
    retentionUntil: new Date(),
    deletedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  } as ProviderDocumentEntity;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        ProviderDocumentService,
        {
          provide: getRepositoryToken(ProviderDocumentEntity),
          useValue: {
            create: jest.fn(
              (value: Partial<ProviderDocumentEntity>) =>
                value as ProviderDocumentEntity,
            ),
            save: jest.fn(),
            findOne: jest.fn(),
            find: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(ProviderDocumentAuditEntity),
          useValue: {
            create: jest.fn(
              (value: Partial<ProviderDocumentAuditEntity>) =>
                value as ProviderDocumentAuditEntity,
            ),
            save: jest.fn(),
          },
        },
        {
          provide: PRIVATE_OBJECT_STORAGE,
          useValue: {
            putQuarantined: jest.fn(),
            readPrivate: jest.fn(),
            delete: jest.fn(),
          },
        },
        { provide: MALWARE_SCANNER, useValue: { scan: jest.fn() } },
      ],
    }).compile();
    service = module.get(ProviderDocumentService);
    documents = module.get(getRepositoryToken(ProviderDocumentEntity));
    audits = module.get(getRepositoryToken(ProviderDocumentAuditEntity));
    storage = module.get(PRIVATE_OBJECT_STORAGE);
    scanner = module.get(MALWARE_SCANNER);
    documents.save.mockImplementation((v) =>
      Promise.resolve({ ...entity, ...v } as ProviderDocumentEntity),
    );
    audits.save.mockResolvedValue({} as ProviderDocumentAuditEntity);
    scanner.scan.mockResolvedValue('clean');
  });

  it('lists only the owner documents newest first', async () => {
    documents.find.mockResolvedValue([entity]);
    await expect(service.listOwn('user-id')).resolves.toEqual([entity]);
    expect(documents.find).toHaveBeenCalledWith({
      where: { userId: 'user-id' },
      order: { createdAt: 'DESC' },
    });
  });

  it('uploads a validated document, scans it, and audits access', async () => {
    const result = await service.upload(
      'user-id',
      'identity',
      'application/pdf',
      pdf,
    );
    expect(storage.putQuarantined).toHaveBeenCalled();
    expect(scanner.scan).toHaveBeenCalledWith(pdf);
    expect(result.status).toBe('available');
    expect(audits.save).toHaveBeenCalled();
  });
  it('rejects MIME spoofing', async () => {
    await expect(
      service.upload('user-id', 'identity', 'image/png', pdf),
    ).rejects.toThrow(BadRequestException);
  });
  it('rejects infected content and deletes quarantine object', async () => {
    scanner.scan.mockResolvedValue('infected');
    await expect(
      service.upload('user-id', 'identity', 'application/pdf', pdf),
    ).rejects.toThrow(BadRequestException);
    expect(storage.delete).toHaveBeenCalled();
  });
  it('denies another provider access', async () => {
    documents.findOne.mockResolvedValue(entity);
    await expect(service.read('other-id', 'doc-id')).rejects.toThrow(
      ForbiddenException,
    );
  });
  it('reads a private object for its owner', async () => {
    documents.findOne.mockResolvedValue(entity);
    storage.readPrivate.mockResolvedValue(pdf);
    await expect(service.read('user-id', 'doc-id')).resolves.toEqual({
      metadata: entity,
      content: pdf,
    });
  });
  it('deletes the object and preserves tombstone metadata', async () => {
    documents.findOne.mockResolvedValue({ ...entity });
    await service.delete('user-id', 'doc-id');
    expect(storage.delete).toHaveBeenCalledWith('quarantine/key');
    expect(documents.save).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'deleted' }),
    );
  });
  it('does not return deleted documents', async () => {
    documents.findOne.mockResolvedValue({ ...entity, status: 'deleted' });
    await expect(service.read('user-id', 'doc-id')).rejects.toThrow(
      NotFoundException,
    );
  });
});
