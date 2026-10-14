import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { S3PrivateObjectStorage } from './s3-private-object-storage';

jest.mock('@aws-sdk/client-s3');

describe('S3PrivateObjectStorage', () => {
  let storage: S3PrivateObjectStorage;
  let mockSend: jest.Mock;
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = {
      ...originalEnv,
      PROVIDER_DOCUMENT_BUCKET: 'test-bucket',
      PROVIDER_DOCUMENT_S3_ENDPOINT: 'http://127.0.0.1:9000',
      PROVIDER_DOCUMENT_S3_REGION: 'us-east-1',
      PROVIDER_DOCUMENT_S3_ACCESS_KEY: 'test-access-key',
      PROVIDER_DOCUMENT_S3_SECRET_KEY: 'test-secret-key',
    };

    mockSend = jest.fn();
    (S3Client as jest.Mock).mockImplementation(() => ({
      send: mockSend,
    }));

    storage = new S3PrivateObjectStorage();
  });

  afterEach(() => {
    process.env = originalEnv;
    jest.clearAllMocks();
  });

  describe('putQuarantined', () => {
    it('sends PutObjectCommand with quarantine metadata', async () => {
      mockSend.mockResolvedValue({});
      const content = Buffer.from('identity-document-bytes');

      await storage.putQuarantined(
        'docs/id-123.pdf',
        content,
        'application/pdf',
      );

      expect(mockSend).toHaveBeenCalledWith(expect.any(PutObjectCommand));
      const commandArg = (PutObjectCommand as unknown as jest.Mock).mock
        .calls[0][0];
      expect(commandArg).toEqual({
        Bucket: 'test-bucket',
        Key: 'docs/id-123.pdf',
        Body: content,
        ContentType: 'application/pdf',
        Metadata: { quarantine: 'true' },
      });
    });
  });

  describe('readPrivate', () => {
    it('retrieves private object bytes via GetObjectCommand', async () => {
      const payload = Buffer.from('hello-private-doc');
      mockSend.mockResolvedValue({
        Body: {
          transformToByteArray: jest
            .fn()
            .mockResolvedValue(new Uint8Array(payload)),
        },
      });

      const buffer = await storage.readPrivate('docs/id-123.pdf');

      expect(buffer).toEqual(payload);
      expect(mockSend).toHaveBeenCalledWith(expect.any(GetObjectCommand));
      const commandArg = (GetObjectCommand as unknown as jest.Mock).mock
        .calls[0][0];
      expect(commandArg).toEqual({
        Bucket: 'test-bucket',
        Key: 'docs/id-123.pdf',
      });
    });

    it('throws error if response Body is missing', async () => {
      mockSend.mockResolvedValue({ Body: null });

      await expect(storage.readPrivate('missing.pdf')).rejects.toThrow(
        'Stored object has no body',
      );
    });
  });

  describe('delete', () => {
    it('sends DeleteObjectCommand with bucket and key', async () => {
      mockSend.mockResolvedValue({});

      await storage.delete('docs/id-123.pdf');

      expect(mockSend).toHaveBeenCalledWith(expect.any(DeleteObjectCommand));
      const commandArg = (DeleteObjectCommand as unknown as jest.Mock).mock
        .calls[0][0];
      expect(commandArg).toEqual({
        Bucket: 'test-bucket',
        Key: 'docs/id-123.pdf',
      });
    });
  });
});
