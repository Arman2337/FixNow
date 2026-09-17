import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listComplaints } from "@/features/operations/api";

const statuses = ["", "OPEN", "IN_REVIEW", "ESCALATED", "RESOLVED", "CLOSED"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

export default async function SupportPage({ searchParams }: { searchParams: Promise<{ search?: string; status?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const params = await searchParams;
  let complaints = await requireManagementResult(await listComplaints());
  
  if (params.search) {
    const s = params.search.toLowerCase();
    complaints = complaints.filter(c => c.id.toLowerCase().includes(s) || c.submitterId.toLowerCase().includes(s));
  }
  if (params.status) {
    complaints = complaints.filter(c => c.status === params.status);
  }

  const escalatedCount = complaints.filter(c => c.status === "ESCALATED").length;

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Complaints & Escrow">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">Trust & Safety Core</span>
                <span className="w-1 h-1 rounded-full bg-outline"></span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Escrow Ledger Linked</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Complaints & Escrow Management</h1>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-space-lg">
            
            {/* LEFT PANE: Dispute Queue */}
            <div className="lg:col-span-4 flex flex-col gap-space-md">
              
              <div className="flex items-center justify-between">
                <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface tracking-tight">Active Dispute Queue</h2>
                <span className="font-data-mono text-data-mono text-error font-bold">{escalatedCount} Escalated</span>
              </div>
              
              <form role="search" className="flex flex-col gap-3">
                <div className="flex items-center bg-surface-container-low rounded-xl px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
                  <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
                  <input
                    id="support-search"
                    name="search"
                    defaultValue={params.search}
                    placeholder="Search Case ID, Customer, Provider..."
                    className="w-full bg-transparent border-none py-2.5 px-2 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
                  />
                </div>
                <div className="flex gap-2">
                  <select
                    id="support-status"
                    name="status"
                    defaultValue={params.status ?? ""}
                    className="flex-1 bg-surface-container-low rounded-xl border border-outline-variant/50 py-2.5 px-3 font-body-sm text-body-sm text-on-surface focus:outline-none focus:border-primary transition-all"
                  >
                    {statuses.map((status) => (
                      <option key={status} value={status}>
                        {status ? status.replaceAll("_", " ") : "All Statuses"}
                      </option>
                    ))}
                  </select>
                  <button className="px-4 py-2.5 rounded-xl bg-primary text-on-primary font-label-md text-label-md font-semibold hover:bg-primary-container transition-colors shadow-sm">
                    Filter
                  </button>
                </div>
              </form>

              <div className="flex flex-col gap-space-sm mt-2">
                {complaints.length === 0 ? (
                  <div className="p-4 rounded-xl border border-outline-variant/30 text-center font-label-sm text-on-surface-variant">
                    No cases match the filters.
                  </div>
                ) : (
                  complaints.map((complaint) => (
                    <Link
                      href={`/support/${complaint.id}`}
                      key={complaint.id}
                      className="p-space-md rounded-xl bg-surface-container-lowest shadow-sm border border-outline-variant/20 hover:shadow-md transition-all cursor-pointer block"
                    >
                      <div className="flex items-start justify-between gap-space-xs mb-1">
                        <div className="flex items-center gap-space-xs">
                          <span className={`font-data-mono text-data-mono font-bold ${complaint.status === 'ESCALATED' ? 'text-error' : 'text-secondary'}`}>#{shortId(complaint.id)}</span>
                          <span className={`px-2 py-0.5 rounded-full font-label-sm text-label-sm ${
                            complaint.status === 'ESCALATED' ? 'bg-error-container text-on-error-container' : 'bg-surface-container-high text-on-surface'
                          }`}>
                            {complaint.status}
                          </span>
                        </div>
                        <span className="font-data-mono text-data-mono text-secondary">{new Date(complaint.createdAt).toLocaleDateString()}</span>
                      </div>
                      <h3 className="font-headline-md text-headline-md text-on-surface leading-snug truncate">
                        {complaint.category}
                      </h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant mt-1 line-clamp-2">
                        {complaint.description}
                      </p>
                      
                      <div className="mt-space-sm pt-space-xs flex items-center justify-between bg-surface-container-low/60 p-2 rounded-lg">
                        <div className="flex items-center gap-space-xs truncate w-1/2">
                          <span className="material-symbols-outlined text-sm text-secondary">person</span>
                          <span className="font-body-sm text-body-sm text-on-surface truncate">#{shortId(complaint.submitterId)}</span>
                        </div>
                        <div className="flex items-center gap-space-xs truncate w-1/2 justify-end">
                          <span className="material-symbols-outlined text-sm text-secondary">target</span>
                          <span className="font-body-sm text-body-sm text-on-surface-variant truncate">#{shortId(complaint.targetId ?? "N/A")}</span>
                        </div>
                      </div>
                    </Link>
                  ))
                )}
              </div>

            </div>

            {/* RIGHT PANE: Placeholder Dossier */}
            <div className="lg:col-span-8 flex flex-col gap-space-lg justify-center items-center bg-surface-container-lowest rounded-xl border border-outline-variant/20 p-8 min-h-[500px]">
              <span className="material-symbols-outlined text-outline text-6xl">gavel</span>
              <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface mt-4">No Case Selected</h2>
              <p className="font-body-md text-body-md text-on-surface-variant">Select a dispute from the queue to view the dossier, evidence, and escrow status.</p>
            </div>
            
          </div>
        </div>
      </div>
    </AdminShell>
  );
}
