import { afterEach, describe, expect, it, vi } from "vitest";
import { loginAdmin, logoutAdmin } from "./api";

afterEach(() => vi.unstubAllGlobals());

describe("admin authentication API", () => {
  it("accepts a staff login response and rejects a non-staff role", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ role: "support_agent" }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ role: "customer" }), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    await expect(loginAdmin("staff@example.com", "secure password")).resolves.toMatchObject({ ok: true });
    await expect(loginAdmin("customer@example.com", "secure password")).resolves.toEqual({ ok: false, status: 403 });
  });

  it("uses the backend logout endpoint and does not expose tokens in a URL", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);
    await expect(logoutAdmin("refresh-token-value")).resolves.toEqual({ ok: true, value: undefined });
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringMatching(/\/auth\/logout$/),
      expect.objectContaining({ method: "POST", body: JSON.stringify({ refreshToken: "refresh-token-value" }) }),
    );
  });
});
