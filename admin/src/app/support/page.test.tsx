import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import SupportPage from "./page";
import { getSession } from "@/auth/session";
import { listComplaints } from "@/features/operations/api";

vi.mock("next/navigation", () => ({ redirect: vi.fn() }));
vi.mock("@/auth/session", () => ({ getSession: vi.fn() }));
vi.mock("@/config/env", () => ({ env: { appEnvironment: "test" } }));
vi.mock("@/features/management-api", () => ({
  requireManagementResult: vi.fn(async (result) => result.value),
}));
vi.mock("@/features/operations/api", () => ({ listComplaints: vi.fn() }));

const authenticatedSession = {
  state: "authenticated" as const,
  session: { userId: "support-agent-1", roles: ["support_agent"] as const },
};

describe("SupportPage", () => {
  beforeEach(() => {
    vi.mocked(getSession).mockResolvedValue(authenticatedSession);
  });

  it("renders an accessible empty support queue", async () => {
    vi.mocked(listComplaints).mockResolvedValue({ ok: true, value: [] } as never);

    const markup = renderToStaticMarkup(
      await SupportPage({ searchParams: Promise.resolve({}) }),
    );

    expect(markup).toContain('role="search"');
    expect(markup).toContain('aria-label="Support results"');
    expect(markup).toContain("No open support cases");
  });

  it("filters case results by status and safe case reference", async () => {
    vi.mocked(listComplaints).mockResolvedValue({
      ok: true,
      value: [
        {
          id: "case-open-1234",
          submitterId: "customer-1",
          targetRole: "PROVIDER",
          category: "Unsafe work",
          description: "The work needs review.",
          status: "OPEN",
          createdAt: "2026-08-21T00:00:00.000Z",
        },
        {
          id: "case-closed-5678",
          submitterId: "customer-2",
          targetRole: "PROVIDER",
          category: "Resolved issue",
          description: "Already resolved.",
          status: "CLOSED",
          createdAt: "2026-08-20T00:00:00.000Z",
        },
      ],
    } as never);

    const markup = renderToStaticMarkup(
      await SupportPage({
        searchParams: Promise.resolve({ search: "open", status: "OPEN" }),
      }),
    );

    expect(markup).toContain("Unsafe work");
    expect(markup).not.toContain("Resolved issue");
    expect(markup).toContain('href="/support/case-open-1234"');
  });
});
