export type ProviderVerificationStatus =
  | "unverified"
  | "under_review"
  | "approved"
  | "rejected"
  | "resubmission_requested";
export interface ProviderVerificationDecisionRequest {
  decision: "approved" | "rejected" | "resubmission_requested";
  reason: string;
  expectedVersion: number;
}
export interface ProviderVerificationEvent {
  id: string;
  applicationId: string;
  actorUserId: string;
  fromStatus: ProviderVerificationStatus;
  toStatus: ProviderVerificationStatus;
  reason: string;
  applicationVersion: number;
  createdAt: Date;
}
