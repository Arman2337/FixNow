/** Shared by the admin form and the backend write boundary. */
export enum GuaranteeClaimStatus {
  PENDING = "PENDING",
  IN_REVIEW = "IN_REVIEW",
  MORE_INFO = "MORE_INFO",
  APPROVED = "APPROVED",
  REJECTED = "REJECTED",
  COMPLETED = "COMPLETED",
}

export const VALID_GUARANTEE_TRANSITIONS: Readonly<
  Record<GuaranteeClaimStatus, readonly GuaranteeClaimStatus[]>
> = {
  PENDING: [
    GuaranteeClaimStatus.IN_REVIEW,
    GuaranteeClaimStatus.APPROVED,
    GuaranteeClaimStatus.REJECTED,
  ],
  IN_REVIEW: [
    GuaranteeClaimStatus.MORE_INFO,
    GuaranteeClaimStatus.APPROVED,
    GuaranteeClaimStatus.REJECTED,
  ],
  MORE_INFO: [
    GuaranteeClaimStatus.IN_REVIEW,
    GuaranteeClaimStatus.APPROVED,
    GuaranteeClaimStatus.REJECTED,
  ],
  APPROVED: [GuaranteeClaimStatus.COMPLETED],
  REJECTED: [],
  COMPLETED: [],
};

export function nextGuaranteeStatuses(
  status: GuaranteeClaimStatus,
): readonly GuaranteeClaimStatus[] {
  return VALID_GUARANTEE_TRANSITIONS[status];
}
