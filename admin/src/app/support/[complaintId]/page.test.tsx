import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import ComplaintDetailPage from "./page";
import { getSession } from "@/auth/session";
import { getComplaint, getUser, listComplaints } from "@/features/operations/api";

vi.mock("next/navigation", () => ({ notFound: vi.fn(), redirect: vi.fn() }));
vi.mock("@/auth/session", () => ({ getSession: vi.fn() }));
vi.mock("@/config/env", () => ({ env: { appEnvironment: "test" } }));
vi.mock("@/features/management-api", () => ({
  requireManagementResult: vi.fn(async (result) => result.value),
}));
vi.mock("@/features/operations/api", () => ({
  getComplaint: vi.fn(),
  getUser: vi.fn(),
  listComplaints: vi.fn(),
}));

const complaint = {
  id: "case-1",
  submitterId: "customer-1",
  targetRole: "PROVIDER",
  targetId: "provider-1",
  category: "Billing question",
  description: "A case that needs review.",
  status: "IN_REVIEW",
  bookingId: "booking-1",
  evidence: [],
  createdAt: "2026-09-18T10:00:00.000Z",
  updatedAt: "2026-09-18T10:00:00.000Z",
  resolutionNotes: null,
};

const session = {
  state: "authenticated" as const,
  session: { userId: "support-1", roles: ["support_agent"] as const },
};

describe("ComplaintDetailPage", () => {
  beforeEach(() => {
    vi.mocked(getSession).mockResolvedValue(session);
    vi.mocked(getComplaint).mockResolvedValue({ ok: true, value: complaint } as never);
    vi.mocked(getUser).mockResolvedValue({ ok: false, status: 503 } as never);
    vi.mocked(listComplaints).mockResolvedValue({ ok: true, value: [complaint] } as never);
  });

  it("does not claim escrow or integration state without an API projection", async () => {
    const markup = renderToStaticMarkup(
      await ComplaintDetailPage({
        params: Promise.resolve({ complaintId: complaint.id }),
        searchParams: Promise.resolve({}),
      }),
    );

    expect(markup).toContain("Management API record");
    expect(markup).toContain("Payment status");
    expect(markup).toContain("Unavailable");
    expect(markup).not.toContain("Escrow Ledger Linked");
    expect(markup).not.toContain("Escrow Locked");
  });
});
