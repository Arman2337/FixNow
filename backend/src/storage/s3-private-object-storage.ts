import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { Injectable } from '@nestjs/common';
import { PrivateObjectStorage } from './private-object-storage';

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value)
    throw new Error(`${name} is required for provider document storage`);
  return value;
}

@Injectable()
export class S3PrivateObjectStorage implements PrivateObjectStorage {
  private readonly bucket =
    process.env.PROVIDER_DOCUMENT_BUCKET ?? 'fixnow-provider-documents';
  private readonly client = new S3Client({
    endpoint:
      process.env.PROVIDER_DOCUMENT_S3_ENDPOINT ?? 'http://127.0.0.1:8333',
    region: process.env.PROVIDER_DOCUMENT_S3_REGION ?? 'local',
    forcePathStyle: true,
    credentials: {
      accessKeyId: requiredEnvironment('PROVIDER_DOCUMENT_S3_ACCESS_KEY'),
      secretAccessKey: requiredEnvironment('PROVIDER_DOCUMENT_S3_SECRET_KEY'),
    },
  });

  async putQuarantined(
    key: string,
    content: Buffer,
    contentType: string,
  ): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: content,
        ContentType: contentType,
        Metadata: { quarantine: 'true' },
      }),
    );
  }
  async readPrivate(key: string): Promise<Buffer> {
    const result = await this.client.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
    );
    if (!result.Body) throw new Error('Stored object has no body');
    return Buffer.from(await result.Body.transformToByteArray());
  }
  async delete(key: string): Promise<void> {
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }
}
