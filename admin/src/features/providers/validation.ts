import type { ProviderStatus } from "./types";

const decisions = new Set<ProviderStatus>(["approved", "rejected", "resubmission_requested"]);

export function validDecision(decision: ProviderStatus, reason: string): boolean {
  const length = reason.trim().length;
  return decisions.has(decision) && length >= 3 && length <= 1000;
}
