import Link from "next/link";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { getProviderApplication, listProviderDocuments, listProviderApplications } from "@/features/providers/api";
import { claimAction, decisionAction } from "@/features/providers/actions";
import { requireManagementResult } from "@/features/management-api";
import { redirect } from "next/navigation";

const statuses = ["", "unverified", "under_review", "approved", "rejected", "resubmission_requested"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

const messages: Record<string, string> = {
  claimed: "Review assigned to you.", decided: "Decision recorded in the audit history.",
  stale: "This application changed. Review the latest version before trying again.",
  forbidden: "This review is not assigned to you.", invalid: "Choose a decision and provide a reason of at least 3 characters.",
  failed: "The action could not be completed. Try again.",
};

export default async function ProviderDetailPage({ params, searchParams }: { params: Promise<{ applicationId: string }>; searchParams: Promise<{ result?: string, search?: string, status?: string, cursor?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const { applicationId } = await params;
  const sParams = await searchParams;
  
  const application = await requireManagementResult(await getProviderApplication(applicationId));
  const assigned = application.assignedReviewerUserId === session.session.userId;
  const canReview = session.session.roles.some((role) => role === "provider_reviewer" || role === "operations_administrator");
  const documents = assigned && canReview ? (await requireManagementResult(await listProviderDocuments(applicationId))).documents : [];
  const result = sParams.result;

  const page = await requireManagementResult(await listProviderApplications(sParams.search, sParams.status, sParams.cursor));

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Provider KYC Verification">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">Identity Engine v4</span>
                <span className="w-1 h-1 rounded-full bg-outline"></span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Synced with DigiLocker</span>
                <span className="px-2 py-0.5 rounded-full bg-primary-fixed text-on-primary-fixed font-data-mono text-[10px] font-bold uppercase tracking-wider">ADR-0016 Active</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Provider KYC Verification</h1>
            </div>
            {result && messages[result] && (
              <div className={`px-4 py-2 rounded-lg ${result === "claimed" || result === "decided" ? "bg-primary-container text-on-primary-container" : "bg-error-container text-on-error-container"} font-label-sm font-bold`}>
                {messages[result]}
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 xl:grid-cols-12 gap-space-lg">
            
            {/* LEFT PANE: Verification Queue */}
            <div className="xl:col-span-4 flex flex-col gap-space-md hidden lg:flex">
              <div className="flex items-center justify-between">
                <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface tracking-tight">Active Queue</h2>
                <span className="font-data-mono text-data-mono text-primary font-bold">{page.items.length} Pending</span>
              </div>

              <form role="search" className="flex flex-col gap-3" action="/providers">
                <div className="flex items-center bg-surface-container-low rounded-xl px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
                  <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
                  <input
                    id="provider-search"
                    name="search"
                    defaultValue={sParams.search}
                    placeholder="Search UID, Phone, Name..."
                    className="w-full bg-transparent border-none py-2.5 px-2 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
                  />
                </div>
                <div className="flex gap-2">
                  <select
                    id="status"
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
                {page.items.map((app) => {
                  const isActive = app.id === applicationId;
                  return (
                    <Link
                      href={`/providers/${app.id}`}
                      key={app.id}
                      className={`p-space-md rounded-2xl shadow-sm hover:shadow-md transition-shadow border cursor-pointer block ${
                        isActive ? "bg-primary-container border-primary" : "bg-surface-container-lowest border-outline-variant/20"
                      }`}
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex items-center gap-space-sm">
                          <div className={`w-10 h-10 rounded-full flex items-center justify-center font-bold font-headline-sm ${
                            isActive ? "bg-primary text-on-primary" : "bg-primary-container text-on-primary-container"
                          }`}>
                            {app.displayName?.[0] ?? "P"}
                          </div>
                          <div>
                            <h3 className={`font-label-md text-label-md font-bold leading-tight ${isActive ? "text-on-primary-container" : "text-on-surface"}`}>{app.displayName ?? "Provider Profile"}</h3>
                            <span className="font-data-mono text-[10px] text-on-surface-variant">UUID: #{shortId(app.id)}</span>
                          </div>
                        </div>
                      </div>
                    </Link>
                  );
                })}
              </div>
            </div>

            {/* RIGHT PANE: Dossier */}
            <div className="xl:col-span-8 flex flex-col gap-space-lg">
              
              <div className="bg-surface-container-lowest p-space-lg rounded-2xl shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-space-md">
                <div className="flex items-center gap-space-lg">
                  <div className="w-16 h-16 rounded-2xl bg-primary-container text-on-primary-container flex items-center justify-center text-2xl font-bold shadow-sm">
                    {application.profile?.displayName?.[0] ?? "P"}
                  </div>
                  <div>
                    <div className="flex flex-wrap items-center gap-space-sm">
                      <h2 className="font-headline-lg text-headline-lg text-[22px] font-bold text-on-surface tracking-tight">{application.profile?.displayName ?? "Unnamed"}</h2>
                      <span className="font-data-mono text-data-mono px-2 py-0.5 rounded bg-surface-container text-on-surface-variant font-bold">UUID: #{shortId(application.id)}</span>
                      <span className="px-2.5 py-0.5 rounded-full bg-primary-container text-on-primary-container font-label-sm text-label-sm font-semibold flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-primary-fixed animate-ping"></span> Live Session
                      </span>
                    </div>
                    <div className="flex flex-wrap items-center gap-x-space-md gap-y-1 font-body-sm text-body-sm text-on-surface-variant mt-1">
                      <span className="flex items-center gap-1"><span className="material-symbols-outlined text-[16px]">location_on</span>{application.profile?.serviceRadiusKm ? `${application.profile.serviceRadiusKm}km coverage` : "No radius set"}</span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-space-sm self-start md:self-auto bg-surface-container-low px-space-md py-space-sm rounded-xl">
                  <div className="text-right">
                    <span className="font-label-sm text-label-sm text-on-surface-variant uppercase block">Application Status</span>
                    <span className="font-price-display text-price-display text-primary font-bold uppercase">{application.status.replace("_", " ")}</span>
                  </div>
                </div>
              </div>

              <div className="bg-surface-container-lowest p-space-lg rounded-2xl shadow-sm flex flex-col gap-space-md">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-space-sm">
                    <span className="material-symbols-outlined text-primary text-[22px]">badge</span>
                    <div>
                      <h3 className="font-headline-md text-headline-md text-[18px] font-bold text-on-surface">1. Statutory Identity Verification & Documents</h3>
                      <p className="font-body-sm text-body-sm text-on-surface-variant">DigiLocker API Direct Integration with UIDAI & NSDL Databases</p>
                    </div>
                  </div>
                  {!assigned ? (
                    <span className="px-2.5 py-1 rounded bg-surface-container text-on-surface-variant font-label-sm text-label-sm font-bold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[15px]">lock</span> LOCKED
                    </span>
                  ) : (
                    <span className="px-2.5 py-1 rounded bg-primary-container text-on-primary-container font-label-sm text-label-sm font-bold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[15px]">lock_open</span> UNLOCKED
                    </span>
                  )}
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-space-md pt-space-xs">
                  {documents.length > 0 ? documents.map((doc) => (
                    <div key={doc.id} className="bg-surface-container-low p-space-md rounded-xl flex flex-col gap-space-sm">
                      <div className="flex items-center justify-between">
                        <span className="font-label-md text-label-md font-bold text-on-surface flex items-center gap-1">
                          <span className="material-symbols-outlined text-[18px] text-primary">description</span> {doc.documentType.toUpperCase()}
                        </span>
                      </div>
                      <div className="flex flex-col gap-1 font-body-sm text-on-surface-variant mt-2">
                        <span>Format: {doc.contentType}</span>
                        <span>Size: {Math.ceil(doc.sizeBytes / 1024)} KB</span>
                        <a href={`/providers/${application.id}/documents/${doc.id}`} target="_blank" rel="noreferrer" className="mt-2 w-fit font-label-sm font-bold text-primary hover:underline flex items-center gap-1">
                          View Document <span className="material-symbols-outlined text-[14px]">open_in_new</span>
                        </a>
                      </div>
                    </div>
                  )) : (
                    <div className="md:col-span-2 p-4 text-center font-body-sm text-on-surface-variant">
                      {!assigned ? "Claim this application to view private documents." : "No documents attached."}
                    </div>
                  )}
                </div>
              </div>

              <div className="bg-surface-container-lowest p-space-lg rounded-2xl shadow-sm flex flex-col gap-space-md">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-space-xs">
                    <span className="material-symbols-outlined text-primary text-[22px]">admin_panel_settings</span>
                    <h3 className="font-headline-md text-headline-md text-[18px] font-bold text-on-surface">Compliance Adjudication</h3>
                  </div>
                  <span className="font-label-sm text-label-sm text-on-surface-variant font-mono">Auditor ID: #{shortId(session.session.userId)}</span>
                </div>

                {application.status === "unverified" && canReview ? (
                  <form action={claimAction} className="mt-4">
                    <input type="hidden" name="applicationId" value={application.id}/>
                    <input type="hidden" name="expectedVersion" value={application.version}/>
                    <button className="px-space-xl py-3 w-full rounded-xl bg-primary text-on-primary font-label-md text-label-md font-bold shadow-md hover:bg-primary-container transition-all flex items-center justify-center gap-2">
                      <span className="material-symbols-outlined text-[20px]">assignment_ind</span>
                      Assign Review to Me
                    </button>
                  </form>
                ) : application.status === "under_review" && assigned && canReview ? (
                  <form action={decisionAction} className="mt-4 flex flex-col gap-space-md">
                    <input type="hidden" name="applicationId" value={application.id}/>
                    <input type="hidden" name="expectedVersion" value={application.version}/>
                    
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-space-md">
                      <div className="md:col-span-2 flex flex-col gap-space-xs">
                        <label htmlFor="reason" className="font-label-sm text-label-sm font-bold uppercase text-on-surface-variant">Internal Auditor Compliance Notes</label>
                        <input id="reason" name="reason" required minLength={3} maxLength={1000} className="w-full px-space-md py-2.5 rounded-xl bg-surface-container-low font-body-sm text-body-sm text-on-surface focus:outline-none focus:bg-surface-container-lowest focus:shadow-sm" type="text" placeholder="Add detailed notes for audit log..."/>
                      </div>
                      <div className="flex flex-col gap-space-xs">
                        <label htmlFor="decision" className="font-label-sm text-label-sm font-bold uppercase text-on-surface-variant">Decision Matrix</label>
                        <select id="decision" name="decision" required className="w-full px-space-md py-2.5 rounded-xl bg-surface-container-low font-body-sm text-body-sm text-on-surface focus:outline-none focus:bg-surface-container-lowest border-r-8 border-transparent">
                          <option value="">-- Select Decision --</option>
                          <option value="approved">Approve & Activate</option>
                          <option value="resubmission_requested">Request Resubmission</option>
                          <option value="rejected">Statutory Rejection</option>
                        </select>
                      </div>
                    </div>

                    <button className="px-space-xl py-3 w-full sm:w-auto rounded-xl bg-primary text-on-primary font-label-md text-label-md font-bold shadow-md hover:bg-primary-container transition-all flex items-center justify-center gap-2">
                      <span className="material-symbols-outlined text-[20px]" style={{fontVariationSettings: "'FILL' 1"}}>check_circle</span>
                      Record Decision & Update Audit Log
                    </button>
                  </form>
                ) : (
                  <div className="p-4 rounded-xl bg-surface-container text-on-surface-variant font-body-sm text-center">
                    {application.status === "under_review" ? "This application is currently under review by another auditor." : "No actions available for this application state."}
                  </div>
                )}
                
                {application.events.length > 0 && (
                  <div className="mt-4 border-t border-outline-variant/30 pt-4">
                    <h4 className="font-label-md font-bold text-on-surface mb-2">Audit History</h4>
                    <div className="flex flex-col gap-2">
                      {application.events.map(event => (
                        <div key={event.id} className="p-2 rounded bg-surface-container-lowest border border-outline-variant/20 flex flex-col">
                          <div className="flex justify-between items-center text-[10px] font-data-mono text-on-surface-variant">
                            <span>Status: {event.toStatus}</span>
                            <span>{new Date(event.createdAt).toLocaleString()}</span>
                          </div>
                          <span className="font-body-sm text-on-surface mt-1">{event.reason}</span>
                        </div>
                      ))}
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
