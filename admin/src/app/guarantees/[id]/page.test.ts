import { describe, expect, it } from "vitest";
import { nextGuaranteeClaimStatuses, GUARANTEE_CLAIM_TRANSITIONS } from "./page";

describe("Guarantee claim status transitions (GAP-07 / GAP-87)", () => {
  it("permits transitions from PENDING", () => {
    const next = nextGuaranteeClaimStatuses("PENDING");
    expect(next).toContain("IN_REVIEW");
    expect(next).toContain("MORE_INFO");
    expect(next).toContain("REJECTED");
    expect(next).not.toContain("COMPLETED");
  });

  it("permits COMPLETED only from APPROVED", () => {
    const fromApproved = nextGuaranteeClaimStatuses("APPROVED");
    expect(fromApproved).toContain("COMPLETED");

    const fromReview = nextGuaranteeClaimStatuses("IN_REVIEW");
    expect(fromReview).not.toContain("COMPLETED");
  });

  it("treats REJECTED and COMPLETED as terminal with no next transitions", () => {
    expect(nextGuaranteeClaimStatuses("REJECTED")).toEqual(["REJECTED"]);
    expect(nextGuaranteeClaimStatuses("COMPLETED")).toEqual(["COMPLETED"]);
    expect(GUARANTEE_CLAIM_TRANSITIONS.REJECTED).toEqual([]);
    expect(GUARANTEE_CLAIM_TRANSITIONS.COMPLETED).toEqual([]);
  });
});
