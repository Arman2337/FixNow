import Link from "next/link";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { listProviderApplications } from "@/features/providers/api";
import { requireManagementResult } from "@/features/management-api";
import { redirect } from "next/navigation";

const statuses = ["", "unverified", "under_review", "approved", "rejected", "resubmission_requested"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

export default async function ProvidersPage({ searchParams }: { searchParams: Promise<{ search?: string; status?: string; cursor?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const params = await searchParams;
  const page = await requireManagementResult(await listProviderApplications(params.search, params.status, params.cursor));

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
          </div>

          <div className="grid grid-cols-1 xl:grid-cols-12 gap-space-lg">
            {/* LEFT PANE: Verification Queue */}
            <div className="xl:col-span-4 flex flex-col gap-space-md">
              <div className="flex items-center justify-between">
                <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface tracking-tight">Active Queue</h2>
                <span className="font-data-mono text-data-mono text-primary font-bold">{page.items.length} Pending</span>
              </div>

              <form role="search" className="flex flex-col gap-3">
                <div className="flex items-center bg-surface-container-low rounded-xl px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
                  <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
                  <input
                    id="provider-search"
                    name="search"
                    defaultValue={params.search}
                    placeholder="Search UID, Phone, Name..."
                    className="w-full bg-transparent border-none py-2.5 px-2 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
                  />
                </div>
                <div className="flex gap-2">
                  <select
                    id="status"
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
                {page.items.length === 0 ? (
                  <div className="p-4 rounded-xl border border-outline-variant/30 text-center font-label-sm text-on-surface-variant">
                    No applications match the filters.
                  </div>
                ) : (
                  page.items.map((application) => (
                    <Link
                      href={`/providers/${application.id}`}
                      key={application.id}
                      className="bg-surface-container-lowest p-space-md rounded-2xl shadow-sm hover:shadow-md transition-shadow border border-outline-variant/20 cursor-pointer block"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex items-center gap-space-sm">
                          <div className="w-10 h-10 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-bold font-headline-sm">
                            {application.displayName?.[0] ?? "P"}
                          </div>
                          <div>
                            <h3 className="font-label-md text-label-md font-bold text-on-surface leading-tight">{application.displayName ?? "Provider Profile"}</h3>
                            <span className="font-data-mono text-[10px] text-on-surface-variant">UUID: #{shortId(application.id)}</span>
                          </div>
                        </div>
                        <div className="flex flex-col items-end">
                          <span className={`px-2 py-0.5 rounded font-label-sm text-[10px] font-bold ${application.status === 'under_review' ? 'bg-secondary-container text-on-secondary-container' : 'bg-surface-container-high text-on-surface-variant'}`}>
                            {application.status.replace("_", " ").toUpperCase()}
                          </span>
                        </div>
                      </div>
                      <div className="flex flex-wrap gap-1.5 pt-space-xs mt-3">
                        <span className="px-2 py-0.5 rounded bg-primary/10 text-primary font-label-sm text-[11px] font-semibold flex items-center gap-1">
                          <span className="material-symbols-outlined text-[13px]">schedule</span> {new Date(application.updatedAt).toLocaleDateString()}
                        </span>
                      </div>
                    </Link>
                  ))
                )}
                {page.nextCursor ? (
                  <Link
                    href={{ pathname: "/providers", query: { search: params.search, status: params.status, cursor: page.nextCursor } }}
                    className="w-full text-center py-2.5 rounded-xl border border-outline-variant/50 font-label-md text-label-md font-semibold hover:bg-surface-container-lowest transition-colors"
                  >
                    Load More
                  </Link>
                ) : null}
              </div>

            </div>

            {/* RIGHT PANE: Placeholder Dossier */}
            <div className="xl:col-span-8 flex flex-col gap-space-lg justify-center items-center bg-surface-container-lowest rounded-2xl border border-outline-variant/20 p-8 min-h-[500px]">
              <span className="material-symbols-outlined text-outline text-6xl">verified_user</span>
              <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface mt-4">No Profile Selected</h2>
              <p className="font-body-md text-body-md text-on-surface-variant">Select a provider application from the queue to begin the verification process.</p>
            </div>
            
          </div>
        </div>
      </div>
    </AdminShell>
  );
}
