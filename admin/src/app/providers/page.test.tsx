import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import ProvidersPage from "./page";
import { getSession } from "@/auth/session";
import { listProviderApplications } from "@/features/providers/api";

vi.mock("next/navigation", () => ({ redirect: vi.fn() }));
vi.mock("@/auth/session", () => ({ getSession: vi.fn() }));
vi.mock("@/config/env", () => ({ env: { appEnvironment: "test" } }));
vi.mock("@/features/management-api", () => ({
  requireManagementResult: vi.fn(async (result) => result.value),
}));
vi.mock("@/features/providers/api", () => ({
  listProviderApplications: vi.fn(),
}));

const session = {
  state: "authenticated" as const,
  session: { userId: "reviewer-1", roles: ["provider_reviewer"] as const },
};

describe("ProvidersPage", () => {
  beforeEach(() => {
    vi.mocked(getSession).mockResolvedValue(session);
    vi.mocked(listProviderApplications).mockResolvedValue({
      ok: true,
      value: { items: [], nextCursor: null },
    } as never);
  });

  it("does not present unverified integrations as live provider facts", async () => {
    const markup = renderToStaticMarkup(
      await ProvidersPage({ searchParams: Promise.resolve({}) }),
    );

    expect(markup).toContain("Management API records");
    expect(markup).not.toContain("Identity Engine v4");
    expect(markup).not.toContain("DigiLocker");
    expect(markup).not.toContain("ADR-0016 Active");
  });
});
