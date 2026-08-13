import { describe, expect, it } from "vitest";
import { validDecision } from "./validation";

describe("provider review validation", () => {
  it("accepts only legal decisions with meaningful bounded reasons", () => {
    expect(validDecision("approved", "requirements satisfied")).toBe(true);
    expect(validDecision("under_review", "requirements satisfied")).toBe(false);
    expect(validDecision("rejected", "  ")).toBe(false);
    expect(validDecision("resubmission_requested", "x".repeat(1001))).toBe(false);
  });
});
