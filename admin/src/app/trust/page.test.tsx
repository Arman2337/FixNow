import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import TrustPage from "./page";
import { getSession } from "@/auth/session";
import { listSignals } from "@/features/trust/api";

vi.mock("next/navigation", () => ({ redirect: vi.fn() }));
vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
}));
vi.mock("@/auth/session", () => ({ getSession: vi.fn() }));
vi.mock("@/config/env", () => ({ env: { appEnvironment: "test" } }));
vi.mock("@/features/management-api", () => ({
  requireManagementResult: vi.fn(async (result) => result.value),
}));
vi.mock("@/features/trust/api", () => ({ listSignals: vi.fn() }));

const authenticatedSession = {
  state: "authenticated" as const,
  session: { userId: "reviewer-1", roles: ["trust_safety_reviewer"] as const },
};

const openSignal = {
  id: "signal-open-1234",
  subjectType: "CUSTOMER",
  subjectId: "customer-9988",
  ruleCode: "customer-cancellation-frequency-v1",
  windowStart: "2026-08-25",
  severity: "LOW",
  evidenceSummary:
    "3 events matched rule customer-cancellation-frequency-v1 in the last 30 days. Requires human review.",
  status: "OPEN",
  createdAt: "2026-08-25T00:00:00.000Z",
};

const reviewedSignal = {
  ...openSignal,
  id: "signal-done-5678",
  status: "REVIEWED",
};

describe("TrustPage", () => {
  beforeEach(() => {
    vi.mocked(getSession).mockResolvedValue(authenticatedSession);
  });

  it("renders an accessible empty queue with an honest explanation", async () => {
    vi.mocked(listSignals).mockResolvedValue({ ok: true, value: [] } as never);

    const markup = renderToStaticMarkup(
      await TrustPage({ searchParams: Promise.resolve({}) }),
    );

    expect(markup).toContain('aria-label="Trust review queue"');
    expect(markup).toContain("No trust signals");
    expect(markup).toContain("advisory threshold");
  });

  it("renders signals with evidence and human-review actions", async () => {
    vi.mocked(listSignals).mockResolvedValue({
      ok: true,
      value: [openSignal],
    } as never);

    const markup = renderToStaticMarkup(
      await TrustPage({ searchParams: Promise.resolve({}) }),
    );

    expect(markup).toContain("Customer cancellations");
    expect(markup).toContain(openSignal.evidenceSummary);
    expect(markup).toContain('value="REVIEWED"');
    expect(markup).toContain('value="DISMISSED"');
  });

  it("filters to open-only when requested and hides actions on reviewed rows", async () => {
    vi.mocked(listSignals).mockResolvedValue({
      ok: true,
      value: [openSignal, reviewedSignal],
    } as never);

    const markup = renderToStaticMarkup(
      await TrustPage({ searchParams: Promise.resolve({ status: "OPEN" }) }),
    );

    expect(markup).toContain("signal-open-1234");
    expect(markup).not.toContain("signal-done-5678");

    const allMarkup = renderToStaticMarkup(
      await TrustPage({ searchParams: Promise.resolve({}) }),
    );
    expect(allMarkup).toContain("Reviewed");
    // The reviewed card exposes no decision actions; only the OPEN one does.
    expect(allMarkup).toContain('value="signal-open-1234"');
    expect(allMarkup).not.toContain('value="signal-done-5678"');
  });
});
