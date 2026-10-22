import { afterEach, describe, expect, it, vi } from "vitest";
import { GET } from "./route";
import { accessToken } from "@/auth/session";

vi.mock("@/auth/session", () => ({ accessToken: vi.fn() }));
vi.mock("@/config/env", () => ({ env: { apiBaseUrl: "http://localhost:3000/api/v1" } }));
afterEach(() => vi.unstubAllGlobals());
const params = Promise.resolve({ applicationId: "application-1", documentId: "document-1" });

describe("provider document proxy", () => {
  it("refuses anonymous requests before fetching document bytes", async () => {
    vi.mocked(accessToken).mockResolvedValue(null);
    const fetchMock = vi.fn(); vi.stubGlobal("fetch", fetchMock);
    expect((await GET(new Request("http://localhost/document"), { params })).status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
  });
  it("preserves upstream refusal and never substitutes a successful empty document", async () => {
    vi.mocked(accessToken).mockResolvedValue("staff-token");
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 403 })));
    expect((await GET(new Request("http://localhost/document"), { params })).status).toBe(403);
  });
  it("streams the requested document privately using its application context", async () => {
    vi.mocked(accessToken).mockResolvedValue("staff-token");
    const fetchMock = vi.fn().mockResolvedValue(new Response("document bytes", { headers: { "content-type": "application/pdf" } }));
    vi.stubGlobal("fetch", fetchMock);
    const response = await GET(new Request("http://localhost/document"), { params });
    expect(fetchMock).toHaveBeenCalledWith("http://localhost:3000/api/v1/admin/provider-applications/application-1/documents/document-1", expect.objectContaining({ cache: "no-store", headers: { authorization: "Bearer staff-token" } }));
    expect(response.headers.get("cache-control")).toBe("no-store, private");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    expect(response.headers.get("content-type")).toBe("application/pdf");
    expect(await response.text()).toBe("document bytes");
  });
});
