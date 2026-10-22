import { GuaranteeClaimStatus, VALID_GUARANTEE_TRANSITIONS } from "../../../../shared/guarantee-lifecycle.types";
import type { GuaranteeStatus } from "./api";

export const GUARANTEE_CLAIM_TRANSITIONS = VALID_GUARANTEE_TRANSITIONS;
export function nextGuaranteeClaimStatuses(currentStatus: string): readonly GuaranteeStatus[] {
  const status = currentStatus.toUpperCase() as GuaranteeClaimStatus;
  const allowed = GUARANTEE_CLAIM_TRANSITIONS[status] ?? [];
  return [status, ...allowed.filter(s => s !== status)];
}
