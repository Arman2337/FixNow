import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listComplaints } from "@/features/operations/api";
import type { StaffRole } from "@/auth/types";

const statuses = ["", "OPEN", "IN_REVIEW", "ESCALATED", "RESOLVED", "CLOSED"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

export default async function SupportPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; status?: string; page?: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");

  const allowedRoles: readonly StaffRole[] = ["support_agent", "trust_safety_reviewer", "operations_administrator"];
  if (!session.session.roles.some((r) => allowedRoles.includes(r))) {
    redirect("/unauthorized");
  }

  const params = await searchParams;
  const pageNumber = Math.max(1, parseInt(params.page ?? "1", 10));
  const pageSize = 20;
  const offset = (pageNumber - 1) * pageSize;

  const complaints = await requireManagementResult(await listComplaints(pageSize + 1, offset));
  const hasNextPage = complaints.length > pageSize;
  const pageItems = complaints.slice(0, pageSize);

  let filtered = pageItems;
  if (params.search) {
    const s = params.search.toLowerCase();
    filtered = filtered.filter(
      (c) => c.id.toLowerCase().includes(s) || c.submitterId.toLowerCase().includes(s) || c.category.toLowerCase().includes(s),
    );
  }
  if (params.status) {
    filtered = filtered.filter((c) => c.status === params.status);
  }

  const escalatedCount = filtered.filter((c) => c.status === "ESCALATED").length;

  return (
    <AdminShell
      environment={env.appEnvironment}
      roles={session.session.roles}
      email={session.session.email}
      displayName={session.session.displayName}
      current="Complaints & Escrow"
    >
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">Trust & Safety Core</span>
                <span className="w-1 h-1 rounded-full bg-outline"></span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Case records from management API</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Complaints & Escrow Management</h1>
            </div>
            <div className="flex items-center gap-3">
              {escalatedCount > 0 && (
                <div className="rounded-xl border border-error/30 bg-error-container/20 px-4 py-2.5 text-sm text-error font-semibold flex items-center gap-1.5">
                  <span className="material-symbols-outlined text-[18px]">warning</span>
                  <span>{escalatedCount} Escalated Case{escalatedCount === 1 ? "" : "s"}</span>
                </div>
              )}
              <div className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest px-4 py-2.5 text-sm text-on-surface">
                <span className="block text-xs uppercase tracking-wider text-on-surface-variant">Showing</span>
                <strong>{filtered.length} dispute{filtered.length === 1 ? "" : "s"}</strong>
              </div>
            </div>
          </div>

          <form role="search" className="flex flex-wrap items-center gap-3 rounded-2xl border border-outline-variant/30 bg-surface-container-low p-3">
            <div className="flex min-w-56 flex-1 items-center bg-surface rounded-xl px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
              <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
              <input
                id="support-search"
                name="search"
                defaultValue={params.search}
                placeholder="Search Case ID, Submitter, Category..."
                className="w-full bg-transparent border-none py-2.5 px-2 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
              />
            </div>
            <select
              id="status"
              name="status"
              defaultValue={params.status ?? ""}
              className="bg-surface rounded-xl border border-outline-variant/50 py-2.5 px-3 font-body-sm text-body-sm text-on-surface focus:outline-none focus:border-primary transition-all"
            >
              {statuses.map((status) => (
                <option key={status} value={status}>
                  {status ? status.replaceAll("_", " ") : "All Statuses"}
                </option>
              ))}
            </select>
            <button type="submit" className="px-5 py-2.5 rounded-xl bg-primary text-on-primary font-label-md text-label-md font-semibold hover:bg-primary-container transition-colors shadow-sm">
              Filter
            </button>
            <Link href="/support" className="px-4 py-2.5 rounded-xl border border-outline-variant/30 bg-surface-container text-on-surface font-label-md text-label-md font-semibold hover:bg-surface-container-high transition-colors">
              Clear
            </Link>
          </form>

          <div aria-label="Support results" className="flex flex-col gap-space-md">
            {filtered.length === 0 ? (
              <div className="p-12 rounded-2xl border border-outline-variant/30 bg-surface-container-lowest text-center">
                <span className="material-symbols-outlined text-4xl text-on-surface-variant mb-2">support_agent</span>
                <h3 className="font-headline-sm text-headline-sm font-bold text-on-surface">No open support cases</h3>
                <p className="mt-1 font-body-sm text-body-sm text-on-surface-variant">No customer or provider complaints match the selected filters.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-space-md">
                {filtered.map((complaint) => (
                  <Link
                    href={`/support/${complaint.id}`}
                    key={complaint.id}
                    className="p-space-md rounded-2xl bg-surface-container-lowest shadow-sm border border-outline-variant/20 hover:shadow-md hover:border-primary/50 transition-all cursor-pointer block"
                  >
                    <div className="flex items-start justify-between gap-space-xs mb-2">
                      <div className="flex items-center gap-space-xs">
                        <span className={`font-data-mono text-data-mono font-bold ${complaint.status === 'ESCALATED' ? 'text-error' : 'text-primary'}`}>
                          #{shortId(complaint.id)}
                        </span>
                        <span className={`px-2 py-0.5 rounded-full font-label-sm text-[10px] font-bold ${
                          complaint.status === 'ESCALATED' ? 'bg-error-container text-on-error-container' : 'bg-surface-container-high text-on-surface'
                        }`}>
                          {complaint.status}
                        </span>
                      </div>
                      <span className="font-data-mono text-xs text-secondary">{new Date(complaint.createdAt).toLocaleDateString()}</span>
                    </div>

                    <h3 className="font-label-lg text-label-lg font-bold text-on-surface leading-snug truncate">
                      {complaint.category}
                    </h3>
                    <p className="font-body-sm text-body-sm text-on-surface-variant mt-1.5 line-clamp-2">
                      {complaint.description}
                    </p>

                    <div className="mt-4 pt-space-xs flex items-center justify-between border-t border-outline-variant/10 text-xs text-on-surface-variant">
                      <div className="flex items-center gap-1 truncate">
                        <span className="material-symbols-outlined text-[15px] text-secondary">person</span>
                        <span className="truncate">Sub: #{shortId(complaint.submitterId)}</span>
                      </div>
                      <div className="flex items-center gap-1 text-primary font-semibold">
                        <span>Details</span>
                        <span className="material-symbols-outlined text-[14px]">arrow_forward</span>
                      </div>
                    </div>
                  </Link>
                ))}
              </div>
            )}

            <div className="flex items-center justify-between border-t border-outline-variant/20 pt-4 mt-2">
              <div>
                {pageNumber > 1 ? (
                  <Link
                    href={{ pathname: "/support", query: { search: params.search, status: params.status, page: String(pageNumber - 1) } }}
                    className="px-4 py-2 rounded-xl border border-outline-variant/40 bg-surface-container-low text-on-surface font-label-md text-sm font-semibold hover:bg-surface-container transition-colors inline-flex items-center gap-1"
                  >
                    <span className="material-symbols-outlined text-[16px]">arrow_back</span>
                    <span>Previous page</span>
                  </Link>
                ) : <div />}
              </div>
              <span className="font-body-sm text-sm text-on-surface-variant">Page {pageNumber}</span>
              <div>
                {hasNextPage ? (
                  <Link
                    href={{ pathname: "/support", query: { search: params.search, status: params.status, page: String(pageNumber + 1) } }}
                    className="px-4 py-2 rounded-xl bg-primary text-on-primary font-label-md text-sm font-semibold hover:bg-primary/90 transition-colors inline-flex items-center gap-1"
                  >
                    <span>Next page</span>
                    <span className="material-symbols-outlined text-[16px]">arrow_forward</span>
                  </Link>
                ) : <div />}
              </div>
            </div>

          </div>

        </div>
      </div>
    </AdminShell>
  );
}
