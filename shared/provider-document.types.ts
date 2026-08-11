export type ProviderDocumentType = "identity" | "license" | "certification";
export type ProviderDocumentStatus =
  "quarantined" | "available" | "rejected" | "deleted";
export interface ProviderDocumentMetadata {
  id: string;
  userId: string;
  documentType: ProviderDocumentType;
  contentType: string;
  sizeBytes: number;
  sha256: string;
  status: ProviderDocumentStatus;
  retentionUntil: Date;
  createdAt: Date;
  updatedAt: Date;
}
