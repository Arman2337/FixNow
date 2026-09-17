import Link from "next/link";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { listUsers } from "@/features/users/api";
import { requireManagementResult } from "@/features/management-api";
import { StatusBadge } from "@/features/status-badge";
import { redirect } from "next/navigation";

const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

const accountLabel = (roles: readonly string[]) => {
  if (roles.some((role) => role.includes("provider"))) return "Provider account";
  if (roles.some((role) => role.includes("administrator") || role.includes("agent") || role.includes("auditor"))) return "Staff account";
  return "Customer account";
};

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ search?: string; cursor?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect(session.state === "unauthorized" ? "/unauthorized" : "/login?reason=expired");
  const params = await searchParams;
  const page = await requireManagementResult(await listUsers(params.search, params.cursor));
  
  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Users & Accounts">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">Identity & Access Management</span>
                <span className="w-1 h-1 rounded-full bg-outline"></span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Global User Registry</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Users & Accounts</h1>
            </div>
          </div>

          <div className="bg-surface-container-lowest rounded-xl shadow-sm border border-outline-variant/30 flex flex-col">
            <div className="p-space-md bg-surface-container-low/40 flex items-center justify-between border-b border-outline-variant/30">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[20px] text-primary">group</span>
                <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface tracking-tight">User Database</h2>
              </div>
            </div>

            <div className="p-space-md border-b border-outline-variant/30">
              <form className="flex flex-col gap-3 sm:flex-row" role="search">
                <label htmlFor="user-search" className="sr-only">Search user ID</label>
                <div className="flex-1 flex items-center bg-surface-container-low rounded-xl px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
                  <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
                  <input 
                    id="user-search" 
                    name="search" 
                    defaultValue={params.search} 
                    placeholder="Search by User ID..." 
                    className="w-full bg-transparent border-none py-2.5 px-2 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
                  />
                </div>
                <button className="min-h-12 rounded-xl bg-primary hover:bg-primary-container px-5 text-on-primary font-label-md font-bold transition-colors shadow-sm">
                  Search
                </button>
                {params.search && (
                  <Link href="/users" className="min-h-12 flex items-center justify-center rounded-xl bg-surface-container text-on-surface hover:bg-surface-container-high px-5 font-label-md font-bold transition-colors">
                    Clear
                  </Link>
                )}
              </form>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse min-w-[800px]">
                <thead>
                  <tr className="bg-surface-container-lowest border-b border-outline-variant/40 font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant">
                    <th className="py-3 px-space-md font-semibold">User Identity</th>
                    <th className="py-3 px-space-md font-semibold">Status</th>
                    <th className="py-3 px-space-md font-semibold">Role Assignments</th>
                    <th className="py-3 px-space-md font-semibold">Created At</th>
                    <th className="py-3 px-space-md font-semibold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-outline-variant/20 font-body-sm text-body-sm text-on-surface">
                  {page.items.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="py-8 text-center font-label-md text-label-md text-on-surface-variant">
                        No users found matching the search criteria.
                      </td>
                    </tr>
                  ) : (
                    page.items.map((user) => (
                      <tr key={user.id} className="hover:bg-surface-container-low/60 transition-colors">
                        <td className="py-3.5 px-space-md">
                          <p className="m-0 font-bold text-on-surface">{accountLabel(user.roles)}</p>
                          <p className="mt-1 mb-0 font-data-mono text-xs text-on-surface-variant">UUID: #{shortId(user.id)}</p>
                        </td>
                        <td className="py-3.5 px-space-md">
                          <StatusBadge status={user.status} />
                        </td>
                        <td className="py-3.5 px-space-md">
                          <div className="flex flex-wrap gap-1">
                            {user.roles.length > 0 ? user.roles.map(r => (
                              <span key={r} className="px-2 py-0.5 rounded bg-surface-container-highest text-on-surface-variant font-label-sm text-[10px] uppercase">
                                {r.replace(/_/g, " ")}
                              </span>
                            )) : (
                              <span className="text-on-surface-variant font-label-sm">No Active Role</span>
                            )}
                          </div>
                        </td>
                        <td className="py-3.5 px-space-md font-data-mono text-on-surface-variant">
                          {new Date(user.createdAt).toLocaleDateString()}
                        </td>
                        <td className="py-3.5 px-space-md text-right">
                          <Link href={`/users/${user.id}`} className="px-3 py-1.5 rounded-lg bg-surface-container text-on-surface hover:bg-surface-container-high transition-colors font-label-sm font-semibold">
                            View Profile
                          </Link>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            {page.nextCursor ? (
              <div className="p-space-md border-t border-outline-variant/30 flex justify-center">
                <Link
                  className="px-4 py-2 rounded-lg border border-outline-variant/50 bg-surface text-on-surface font-label-md text-label-md font-semibold hover:bg-surface-container-low transition-colors shadow-sm"
                  href={{
                    pathname: "/users",
                    query: { search: params.search, cursor: page.nextCursor },
                  }}
                >
                  Load Next Segment →
                </Link>
              </div>
            ) : null}
          </div>

        </div>
      </div>
    </AdminShell>
  );
}
