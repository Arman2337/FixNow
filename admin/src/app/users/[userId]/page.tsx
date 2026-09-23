import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { StatusBadge } from "@/features/status-badge";
import { getUser } from "@/features/users/api";

const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();
const accountLabel = (roles: readonly string[]) => roles.some((role) => role.includes("provider")) ? "Provider account" : roles.some((role) => role.includes("administrator") || role.includes("agent") || role.includes("auditor")) ? "Staff account" : "Customer account";

export default async function UserDetailPage({ params }: { params: Promise<{ userId: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const { userId } = await params;
  const user = await requireManagementResult(await getUser(userId));
  
  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Users & Accounts">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg max-w-4xl">
          
          <Link href="/users" className="flex items-center gap-2 font-label-md text-primary hover:underline self-start">
            <span className="material-symbols-outlined text-sm">arrow_back</span>
            Back to Users Registry
          </Link>

          <header className="flex flex-col sm:flex-row sm:items-start justify-between gap-space-md border-b border-outline-variant/30 pb-space-md">
            <div>
              <p className="font-label-sm uppercase tracking-wider text-secondary">Account Profile</p>
              <h1 className="mt-1 font-headline-md text-headline-md font-bold text-on-surface">{accountLabel(user.roles)}</h1>
              <div className="mt-2 flex items-center gap-2 text-on-surface-variant">
                <span className="material-symbols-outlined text-sm">badge</span>
                <span className="font-data-mono text-sm">#{shortId(user.id)}</span>
              </div>
            </div>
            <StatusBadge status={user.status}/>
          </header>

          <section aria-labelledby="account-overview" className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-space-lg shadow-sm">
            <div className="flex items-center gap-2 mb-space-md">
              <span className="material-symbols-outlined text-primary text-xl">person</span>
              <h2 id="account-overview" className="m-0 font-headline-sm text-headline-sm font-bold text-on-surface">Account Overview</h2>
            </div>
            <p className="mb-6 font-body-sm text-on-surface-variant">Only operationally necessary account metadata is available here due to privacy constraints.</p>
            
            <dl className="grid grid-cols-1 sm:grid-cols-2 gap-y-6 gap-x-8 border-t border-outline-variant/30 pt-6">
              <div>
                <dt className="font-label-sm uppercase text-secondary">Account Type</dt>
                <dd className="mt-1 font-body-md font-semibold text-on-surface">{accountLabel(user.roles)}</dd>
              </div>
              <div>
                <dt className="font-label-sm uppercase text-secondary">Roles</dt>
                <dd className="mt-1 flex flex-wrap gap-1">
                  {user.roles.length > 0 ? user.roles.map(r => (
                    <span key={r} className="px-2 py-0.5 rounded bg-surface-container-high text-on-surface font-label-sm uppercase">{r.replace(/_/g, " ")}</span>
                  )) : (
                    <span className="text-on-surface-variant font-body-sm">No active role</span>
                  )}
                </dd>
              </div>
              <div>
                <dt className="font-label-sm uppercase text-secondary">Created</dt>
                <dd className="mt-1 font-data-mono text-sm text-on-surface">{new Date(user.createdAt).toLocaleString()}</dd>
              </div>
              <div>
                <dt className="font-label-sm uppercase text-secondary">Last Updated</dt>
                <dd className="mt-1 font-data-mono text-sm text-on-surface">{new Date(user.updatedAt).toLocaleString()}</dd>
              </div>
            </dl>
          </section>

          <section aria-labelledby="account-reference" className="rounded-xl border border-outline-variant/30 bg-surface-container-low p-space-md">
            <h2 id="account-reference" className="font-label-md font-bold text-on-surface">System Reference</h2>
            <p className="mt-1 font-data-mono text-sm text-secondary">Short ID: #{shortId(user.id)}</p>
            <details className="mt-3 group">
              <summary className="cursor-pointer font-label-sm text-primary hover:underline list-none flex items-center gap-1">
                <span className="material-symbols-outlined text-sm group-open:rotate-180 transition-transform">expand_more</span>
                Show Full UUID
              </summary>
              <p className="mt-2 font-data-mono text-xs text-on-surface-variant break-all bg-surface-container-lowest p-2 rounded border border-outline-variant/30">
                {user.id}
              </p>
            </details>
          </section>

        </div>
      </div>
    </AdminShell>
  );
}
