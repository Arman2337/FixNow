import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import GuaranteesPage from "./guarantees/page";
import ServicesPage from "./services/page";
import SearchPage from "./search/page";
import { getSession } from "@/auth/session";
import { listClaims } from "@/features/guarantees/api";
import { listBookings, listCategories, listComplaints } from "@/features/operations/api";
import { listProviderApplications } from "@/features/providers/api";

vi.mock("next/navigation", () => ({ redirect: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("@/auth/session", () => ({ getSession: vi.fn() }));
vi.mock("@/config/env", () => ({ env: { appEnvironment: "test" } }));
vi.mock("@/features/management-api", () => ({ requireManagementResult: vi.fn(async r => r.value) }));
vi.mock("@/features/operations/api", () => ({ listBookings: vi.fn(), listCategories: vi.fn(), listComplaints: vi.fn() }));
vi.mock("@/features/providers/api", () => ({ listProviderApplications: vi.fn() }));
vi.mock("@/features/guarantees/api", () => ({ listClaims: vi.fn() }));

describe("bounded admin lists and global search", () => {
  beforeEach(() => {
    vi.mocked(getSession).mockResolvedValue({ state: "authenticated", session: { userId: "operator", roles: ["operations_administrator"] } });
  });

  it("continues guarantees beyond the former 50-record cap and preserves status", async () => {
    vi.mocked(listClaims).mockResolvedValue({ ok: true, value: Array.from({ length: 11 }, (_, i) => ({
      id: `claim-${60 + i}`, bookingId: "booking", status: "PENDING", description: `Repair ${60 + i}`, createdAt: "2026-10-01",
    })) } as never);
    const markup = renderToStaticMarkup(await GuaranteesPage({ searchParams: Promise.resolve({ page: "7", status: "PENDING" }) }));
    expect(listClaims).toHaveBeenCalledWith("PENDING", 11, 60, undefined);
    expect(markup).toContain("Repair 60");
    expect(markup).not.toContain("Repair 70");
    expect(markup).toContain("page=8");
    expect(markup).toContain("status=PENDING");
    expect(markup).not.toContain("of 5");
  });

  it("requests catalog pagination from the server and retains navigation on empty later pages", async () => {
    vi.mocked(listCategories).mockResolvedValue({ ok: true, value: [] });
    const markup = renderToStaticMarkup(await ServicesPage({ searchParams: Promise.resolve({ page: "4" }) }));
    expect(listCategories).toHaveBeenCalledWith(9, 24);
    expect(markup).toContain("Previous page");
    expect(markup).not.toContain("Next page");
  });

  it("searches complaints and guarantees at the source instead of filtering the newest page", async () => {
    vi.mocked(listBookings).mockResolvedValue({ ok: true, value: { items: [], nextCursor: null } });
    vi.mocked(listProviderApplications).mockResolvedValue({ ok: true, value: { items: [], nextCursor: null } });
    vi.mocked(listComplaints).mockResolvedValue({ ok: true, value: [{ id: "old-complaint", status: "OPEN", category: "leak" }] } as never);
    vi.mocked(listClaims).mockResolvedValue({ ok: true, value: [{ id: "old-claim", status: "PENDING", description: "leak repair" }] } as never);
    const markup = renderToStaticMarkup(await SearchPage({ searchParams: Promise.resolve({ q: "leak" }) }));
    expect(listComplaints).toHaveBeenCalledWith(20, 0, undefined, "leak");
    expect(listClaims).toHaveBeenCalledWith(undefined, 20, 0, "leak");
    expect(markup).toContain('href="/support/old-complaint"');
    expect(markup).toContain('href="/guarantees/old-claim"');
  });
});
