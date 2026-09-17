import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { updateComplaintStatusAction } from "@/features/operations/actions";
import { getComplaint, getUser, listComplaints } from "@/features/operations/api";

const selectableStatuses = ["OPEN", "IN_REVIEW", "ESCALATED", "RESOLVED", "CLOSED"];
const statuses = ["", "OPEN", "IN_REVIEW", "ESCALATED", "RESOLVED", "CLOSED"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

const labels: Record<string, string> = { 
  updated: "Case status successfully updated.",
  failed: "The action could not be completed."
};

export default async function ComplaintDetailPage({ params, searchParams }: { params: Promise<{ complaintId: string }>; searchParams: Promise<{ result?: string; search?: string; status?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const { complaintId } = await params;
  const sParams = await searchParams;
  const response = await getComplaint(complaintId);
  if (!response.ok && response.status === 404) notFound();
  const complaint = await requireManagementResult(response);
  const { result } = sParams;

  const [submitterRes, targetRes] = await Promise.all([
    getUser(complaint.submitterId),
    complaint.targetId ? getUser(complaint.targetId) : Promise.resolve(null),
  ]);

  const submitter = submitterRes?.ok ? submitterRes.value : null;
  const target = targetRes?.ok ? targetRes.value : null;
  const canIntervene = session.session.roles.some((role) => role === "support_agent" || role === "trust_safety_reviewer" || role === "operations_administrator");
  
  let complaints = await requireManagementResult(await listComplaints());
  if (sParams.search) {
    const s = sParams.search.toLowerCase();
    complaints = complaints.filter(c => c.id.toLowerCase().includes(s) || c.submitterId.toLowerCase().includes(s));
  }
  if (sParams.status) {
    complaints = complaints.filter(c => c.status === sParams.status);
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
            {result && labels[result] && (
              <div className={`px-4 py-2 rounded-lg ${result === "updated" ? "bg-primary-container text-on-primary-container" : "bg-error-container text-on-error-container"} font-label-sm font-bold`}>
                {labels[result]}
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-space-lg">
            
            {/* LEFT PANE: Dispute Queue */}
            <div className="lg:col-span-4 flex flex-col gap-space-md hidden lg:flex">
              
              <div className="flex items-center justify-between">
                <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface tracking-tight">Active Dispute Queue</h2>
                <span className="font-data-mono text-data-mono text-error font-bold">{escalatedCount} Escalated</span>
              </div>
              
              <form role="search" className="flex flex-col gap-3" action="/support">
                <div className="flex items-center bg-surface-container-low rounded-xl px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
                  <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
                  <input
                    id="support-search"
                    name="search"
                    defaultValue={sParams.search}
                    placeholder="Search Case ID..."
                    className="w-full bg-transparent border-none py-2.5 px-2 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
                  />
                </div>
                <div className="flex gap-2">
                  <select
                    id="support-status"
                    name="status"
                    defaultValue={sParams.status ?? ""}
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
                {complaints.map((c) => {
                  const isActive = c.id === complaint.id;
                  return (
                    <Link
                      href={`/support/${c.id}`}
                      key={c.id}
                      className={`p-space-md rounded-xl shadow-sm border transition-all cursor-pointer block ${
                        isActive ? "bg-primary-container border-primary" : "bg-surface-container-lowest border-outline-variant/20 hover:shadow-md"
                      }`}
                    >
                      <div className="flex items-start justify-between gap-space-xs mb-1">
                        <div className="flex items-center gap-space-xs">
                          <span className={`font-data-mono text-data-mono font-bold ${c.status === 'ESCALATED' ? 'text-error' : isActive ? 'text-on-primary-container' : 'text-secondary'}`}>#{shortId(c.id)}</span>
                          <span className={`px-2 py-0.5 rounded-full font-label-sm text-[10px] ${
                            c.status === 'ESCALATED' ? 'bg-error-container text-on-error-container' : isActive ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface'
                          }`}>
                            {c.status}
                          </span>
                        </div>
                      </div>
                      <h3 className={`font-label-md text-label-md font-bold leading-snug truncate ${isActive ? 'text-on-primary-container' : 'text-on-surface'}`}>
                        {c.category}
                      </h3>
                    </Link>
                  )
                })}
              </div>

            </div>

            {/* RIGHT PANE: Incident Dossier */}
            <div className="lg:col-span-8 flex flex-col gap-space-lg">
              
              <div className="bg-surface-container-lowest rounded-xl p-space-lg shadow-sm border border-outline-variant/20">
                <div className="flex flex-col md:flex-row md:items-center justify-between pb-space-md gap-space-sm border-b border-outline-variant/30 mb-space-md">
                  <div className="flex flex-col">
                    <div className="flex items-center gap-space-xs">
                      <span className="font-headline-md text-headline-md font-bold text-on-surface tracking-tight">Incident #{shortId(complaint.id)}</span>
                      {complaint.status === "ESCALATED" && (
                        <span className="px-2 py-0.5 rounded-full bg-error-container text-on-error-container font-label-sm text-label-sm uppercase font-semibold">Priority: High</span>
                      )}
                    </div>
                    <div className="flex flex-wrap items-center gap-space-xs mt-1 text-secondary font-body-sm">
                      {complaint.bookingId && (
                        <>
                          <Link href={`/bookings/${complaint.bookingId}`} className="font-data-mono text-data-mono font-bold text-primary hover:underline">
                            Booking #{shortId(complaint.bookingId)}
                          </Link>
                          <span>?</span>
                        </>
                      )}
                      <span>{new Date(complaint.createdAt).toLocaleString()}</span>
                    </div>
                  </div>
                  
                  {complaint.bookingId && (
                    <div className="flex items-center gap-space-xs bg-surface-container-low px-space-md py-2 rounded-xl border border-outline-variant/30">
                      <span className="material-symbols-outlined text-primary text-xl">shield_lock</span>
                      <div className="flex flex-col">
                        <span className="font-label-sm text-label-sm text-secondary leading-none uppercase">Escrow Locked</span>
                        <span className="font-price-display text-price-display text-primary font-bold">YES</span>
                      </div>
                    </div>
                  )}
                </div>

                <div className="p-space-md rounded-xl bg-surface-container-low mb-space-lg border border-outline-variant/30">
                  <div className="flex items-start gap-space-sm">
                    <span className="material-symbols-outlined text-tertiary text-xl mt-0.5">report_problem</span>
                    <div className="flex flex-col w-full">
                      <div className="flex justify-between items-center w-full">
                        <span className="font-label-md text-label-md font-bold text-on-surface uppercase tracking-wide">Dispute Summary & Core Allegation ({complaint.category})</span>
                      </div>
                      <p className="font-body-md text-body-md text-on-surface-variant mt-2 leading-relaxed whitespace-pre-wrap">
                        {complaint.description}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-space-md mb-space-lg">
                  <div className="p-space-md rounded-xl bg-surface-container-low flex flex-col gap-space-xs border border-outline-variant/30">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-space-xs">
                        <span className="material-symbols-outlined text-secondary">person</span>
                        <span className="font-label-md text-label-md text-on-surface font-semibold">Submitter</span>
                      </div>
                      <span className="font-data-mono text-[10px] text-on-surface-variant">ID: {shortId(complaint.submitterId)}</span>
                    </div>
                    {submitter ? (
                      <div className="mt-2 flex flex-col font-body-sm text-on-surface-variant">
                        <span className="font-bold text-on-surface">{submitter.name}</span>
                        <span>{submitter.email}</span>
                        <span>Role: {complaint.targetRole === "PROVIDER" ? "CUSTOMER" : "PROVIDER"}</span>
                      </div>
                    ) : (
                      <span className="mt-2 font-body-sm text-on-surface-variant">Details unavailable</span>
                    )}
                  </div>
                  
                  <div className="p-space-md rounded-xl bg-surface-container-low flex flex-col gap-space-xs border border-outline-variant/30">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-space-xs">
                        <span className="material-symbols-outlined text-secondary">target</span>
                        <span className="font-label-md text-label-md text-on-surface font-semibold">Target ({complaint.targetRole})</span>
                      </div>
                      <span className="font-data-mono text-[10px] text-on-surface-variant">ID: {complaint.targetId ? shortId(complaint.targetId) : "N/A"}</span>
                    </div>
                    {target ? (
                      <div className="mt-2 flex flex-col font-body-sm text-on-surface-variant">
                        <span className="font-bold text-on-surface">{target.name}</span>
                        <span>{target.email}</span>
                      </div>
                    ) : (
                      <span className="mt-2 font-body-sm text-on-surface-variant">Target details unavailable</span>
                    )}
                  </div>
                </div>

                {complaint.evidence && complaint.evidence.length > 0 && (
                  <div className="mb-space-lg">
                    <div className="flex items-center justify-between mb-space-sm">
                      <h4 className="font-label-md text-label-md font-bold uppercase tracking-wider text-secondary">Evidence Dossier</h4>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-space-md">
                      {complaint.evidence.map(ev => (
                        <div key={ev.id} className="flex flex-col gap-2 bg-surface-container-low rounded-xl p-space-sm border border-outline-variant/30">
                          <div className="flex items-center gap-2">
                            <span className="material-symbols-outlined text-primary">description</span>
                            <span className="font-label-sm font-bold text-on-surface truncate">{ev.fileType.toUpperCase()}</span>
                          </div>
                          {ev.description && (
                            <span className="font-body-sm text-on-surface-variant line-clamp-2">{ev.description}</span>
                          )}
                          <a href={ev.fileUrl} target="_blank" rel="noreferrer" className="mt-auto w-fit text-[11px] font-bold text-primary flex items-center gap-1 hover:underline">
                            OPEN FILE <span className="material-symbols-outlined text-[14px]">open_in_new</span>
                          </a>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                
                {canIntervene && (
                  <div className="mt-space-lg border-t border-outline-variant/30 pt-space-lg">
                    <div className="flex items-center gap-2 mb-space-md">
                      <span className="material-symbols-outlined text-primary text-[22px]">admin_panel_settings</span>
                      <h3 className="font-headline-md text-headline-md font-bold text-on-surface">Case Adjudication & Resolution</h3>
                    </div>
                    
                    <form action={updateComplaintStatusAction} className="flex flex-col gap-space-md">
                      <input type="hidden" name="id" value={complaint.id} />
                      
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-space-md">
                        <div className="md:col-span-2 flex flex-col gap-space-xs">
                          <label htmlFor="resolutionNotes" className="font-label-sm text-label-sm font-bold uppercase text-on-surface-variant">Resolution / Audit Notes</label>
                          <textarea 
                            id="resolutionNotes" 
                            name="resolutionNotes" 
                            defaultValue={complaint.resolutionNotes ?? ""}
                            placeholder="Enter detailed notes for case resolution or escalation..."
                            className="w-full px-space-md py-3 rounded-xl bg-surface-container-low font-body-sm text-body-sm text-on-surface focus:outline-none focus:bg-surface-container-lowest border border-outline-variant/50 focus:border-primary transition-all min-h-[100px]"
                          />
                        </div>
                        <div className="flex flex-col gap-space-xs">
                          <label htmlFor="status" className="font-label-sm text-label-sm font-bold uppercase text-on-surface-variant">Update Status</label>
                          <select 
                            id="status" 
                            name="status" 
                            defaultValue={complaint.status} 
                            className="w-full px-space-md py-3 rounded-xl bg-surface-container-low font-body-sm text-body-sm text-on-surface focus:outline-none focus:bg-surface-container-lowest border border-outline-variant/50 focus:border-primary transition-all"
                          >
                            {selectableStatuses.map(status => (
                              <option key={status} value={status}>{status.replaceAll("_", " ")}</option>
                            ))}
                          </select>
                        </div>
                      </div>

                      <div className="flex justify-end mt-2">
                        <button className="px-space-xl py-3 rounded-xl bg-primary text-on-primary font-label-md text-label-md font-bold shadow-md hover:bg-primary-container transition-all flex items-center justify-center gap-2">
                          <span className="material-symbols-outlined text-[20px]" style={{fontVariationSettings: "'FILL' 1"}}>gavel</span>
                          Execute Adjudication
                        </button>
                      </div>
                    </form>
                  </div>
                )}

                {!canIntervene && complaint.resolutionNotes && (
                  <div className="mt-space-lg border-t border-outline-variant/30 pt-space-lg">
                    <h3 className="font-label-md font-bold uppercase text-secondary mb-2">Resolution Notes</h3>
                    <div className="p-space-md rounded-xl bg-surface-container-low border border-outline-variant/30">
                      <p className="font-body-sm text-on-surface whitespace-pre-wrap">{complaint.resolutionNotes}</p>
                    </div>
                  </div>
                )}
                
              </div>
            </div>
            
          </div>
        </div>
      </div>
    </AdminShell>
  );
}
