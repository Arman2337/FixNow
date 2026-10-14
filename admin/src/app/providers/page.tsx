import Link from "next/link";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { listProviderApplications } from "@/features/providers/api";
import { requireManagementResult } from "@/features/management-api";
import { redirect } from "next/navigation";
import type { StaffRole } from "@/auth/types";

const statuses = ["", "unverified", "under_review", "approved", "rejected", "resubmission_requested"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

export default async function ProvidersPage({ searchParams }: { searchParams: Promise<{ search?: string; status?: string; cursor?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");

  const allowedRoles: readonly StaffRole[] = ["provider_reviewer", "operations_administrator", "auditor"];
  if (!session.session.roles.some((r) => allowedRoles.includes(r))) {
    redirect("/unauthorized");
  }

  const params = await searchParams;
  const page = await requireManagementResult(await listProviderApplications(params.search, params.status, params.cursor));

  return (
    <AdminShell
      environment={env.appEnvironment}
      roles={session.session.roles}
      email={session.session.email}
      displayName={session.session.displayName}
      current="Providers & KYC Verification"
    >
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">Provider verification queue</span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Management API records</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Provider KYC Verification</h1>
            </div>
            <div className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest px-4 py-3 text-sm text-on-surface">
              <span className="block text-xs uppercase tracking-wider text-on-surface-variant">Active applications</span>
              <strong>{page.items.length} provider{page.items.length === 1 ? "" : "s"}</strong>
            </div>
          </div>

          <form role="search" className="flex flex-wrap items-center gap-3 rounded-2xl border border-outline-variant/30 bg-surface-container-low p-3">
            <div className="flex min-w-56 flex-1 items-center bg-surface rounded-xl px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
              <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
              <input
                id="provider-search"
                name="search"
                defaultValue={params.search}
                placeholder="Search UID, Phone, Name..."
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
            <Link href="/providers" className="px-4 py-2.5 rounded-xl border border-outline-variant/30 bg-surface-container text-on-surface font-label-md text-label-md font-semibold hover:bg-surface-container-high transition-colors">
              Clear
            </Link>
          </form>

          <div className="flex flex-col gap-space-md">
            {page.items.length === 0 ? (
              <div className="p-12 rounded-2xl border border-outline-variant/30 bg-surface-container-lowest text-center">
                <span className="material-symbols-outlined text-4xl text-on-surface-variant mb-2">person_search</span>
                <h3 className="font-headline-sm text-headline-sm font-bold text-on-surface">No applications found</h3>
                <p className="mt-1 font-body-sm text-body-sm text-on-surface-variant">No provider applications match the chosen filters.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-space-md">
                {page.items.map((application) => (
                  <Link
                    href={`/providers/${application.id}`}
                    key={application.id}
                    className="bg-surface-container-lowest p-space-md rounded-2xl shadow-sm hover:shadow-md transition-shadow border border-outline-variant/20 cursor-pointer block hover:border-primary/50"
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
                    <div className="flex flex-wrap items-center justify-between gap-1.5 pt-space-xs mt-4 border-t border-outline-variant/10">
                      <span className="px-2 py-0.5 rounded bg-primary/10 text-primary font-label-sm text-[11px] font-semibold flex items-center gap-1">
                        <span className="material-symbols-outlined text-[13px]">schedule</span> {new Date(application.updatedAt).toLocaleDateString()}
                      </span>
                      <span className="text-xs text-primary font-semibold flex items-center gap-0.5">
                        Review application <span className="material-symbols-outlined text-[14px]">arrow_forward</span>
                      </span>
                    </div>
                  </Link>
                ))}
              </div>
            )}

            {page.nextCursor ? (
              <div className="flex justify-center p-4">
                <Link
                  href={{ pathname: "/providers", query: { search: params.search, status: params.status, cursor: page.nextCursor } }}
                  className="px-6 py-2.5 rounded-xl bg-primary text-on-primary font-label-md text-label-md font-semibold hover:bg-primary/90 transition-colors inline-flex items-center gap-2"
                >
                  <span>Load more</span>
                  <span className="material-symbols-outlined text-[18px]">arrow_forward</span>
                </Link>
              </div>
            ) : null}
          </div>

        </div>
      </div>
    </AdminShell>
  );
}
