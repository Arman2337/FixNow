import { describe, expect, it } from "vitest";
import { classifySession } from "./session";

describe("admin session classification", () => {
  it("distinguishes anonymous and refreshable expired sessions", () => {
    expect(classifySession(false, false)).toEqual({ state: "anonymous" });
    expect(classifySession(false, true)).toEqual({ state: "expired" });
  });

  it("distinguishes unauthorized and authenticated sessions", () => {
    expect(classifySession(true, true, { ok: false, status: 403 })).toEqual({ state: "unauthorized" });
    const session = { userId: "staff-1", roles: ["support_agent"] as const };
    expect(classifySession(true, true, { ok: true, value: session })).toEqual({ state: "authenticated", session });
  });
});
