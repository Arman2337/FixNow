export type ProviderStatus = "unverified" | "under_review" | "approved" | "rejected" | "resubmission_requested";
export type ProviderApplicationSummary = Readonly<{
  id: string;
  userId: string;
  displayName?: string | null;
  status: ProviderStatus;
  assignedReviewerUserId: string | null;
  decisionReason: string | null;
  reviewedAt: string | null;
  version: number;
  createdAt: string;
  updatedAt: string;
}>;
export type VerificationEvent = Readonly<{ id: string; actorUserId: string; fromStatus: ProviderStatus; toStatus: ProviderStatus; reason: string; applicationVersion: number; createdAt: string }>;
export type ProviderApplicationDetail = ProviderApplicationSummary & Readonly<{
  profile: { displayName: string; bio: string | null; serviceRadiusKm: number } | null;
  events: readonly VerificationEvent[];
}>;
export type ProviderApplicationPage = Readonly<{ items: readonly ProviderApplicationSummary[]; nextCursor: string | null }>;
export type ProviderDocument = Readonly<{ id: string; documentType: string; contentType: string; sizeBytes: number; status: string; retentionUntil: string; createdAt: string }>;
