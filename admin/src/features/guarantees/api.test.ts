import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("@/auth/session", () => ({
  accessToken: vi.fn().mockResolvedValue("access-token"),
}));

vi.mock("@/config/env", () => ({
  env: { apiBaseUrl: "http://localhost:3000/api/v1" },
}));

import { getClaim, listClaims, scheduleReService, updateClaimStatus } from "./api";

afterEach(() => vi.unstubAllGlobals());

describe("guarantee management API", () => {
  it("uses the management API for claim listing and detail", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: "claim-1" }), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    await listClaims("OPEN");
    await getClaim("claim-1");

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "http://localhost:3000/api/v1/guarantees/claims?status=OPEN",
      expect.objectContaining({ cache: "no-store", headers: expect.objectContaining({ authorization: "Bearer access-token" }) }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "http://localhost:3000/api/v1/guarantees/claims/claim-1",
      expect.objectContaining({ headers: expect.objectContaining({ authorization: "Bearer access-token" }) }),
    );
  });

  it("sends confirmed status and re-service mutations", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: "claim-1", status: "IN_REVIEW" }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: "booking-1" }), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    await updateClaimStatus("claim-1", "IN_REVIEW");
    await scheduleReService("claim-1", "provider-1");

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "http://localhost:3000/api/v1/guarantees/claims/claim-1/status",
      expect.objectContaining({ method: "PATCH", body: JSON.stringify({ status: "IN_REVIEW" }) }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "http://localhost:3000/api/v1/guarantees/claims/claim-1/re-service",
      expect.objectContaining({ method: "POST", body: JSON.stringify({ providerId: "provider-1" }) }),
    );
  });
});
