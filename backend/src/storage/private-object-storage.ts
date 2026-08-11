export const PRIVATE_OBJECT_STORAGE = Symbol('PRIVATE_OBJECT_STORAGE');

export interface PrivateObjectStorage {
  putQuarantined(
    key: string,
    content: Buffer,
    contentType: string,
  ): Promise<void>;
  readPrivate(key: string): Promise<Buffer>;
  delete(key: string): Promise<void>;
}
