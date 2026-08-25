export type TrustSignalStatus = "OPEN" | "REVIEWED" | "DISMISSED";

/** FN-113: reviewable advisory signal produced by the deterministic FN-060/FN-055 rules. */
export type TrustSignalSummary = {
  id: string;
  subjectType: "CUSTOMER" | "PROVIDER" | string;
  subjectId: string;
  ruleCode: string;
  windowStart: string;
  severity: "LOW" | "MEDIUM" | "HIGH" | string;
  evidenceSummary: string;
  status: TrustSignalStatus;
  createdAt: string;
};
