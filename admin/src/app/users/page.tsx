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
  return <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Users">
    <header className="border-b border-[var(--color-border-default)] pb-6"><p className="m-0 text-sm font-semibold uppercase tracking-[0.08em] text-[var(--color-primary)]">Account operations</p><h1 className="mt-2 mb-0 text-3xl font-bold leading-10">Users</h1><p className="mt-2 mb-0 max-w-2xl text-[var(--color-text-secondary)]">Find an account and inspect its authorised operational record. Contact details and credentials are intentionally excluded.</p></header>
    <form className="mt-6 flex flex-col gap-3 sm:flex-row" role="search"><label htmlFor="user-search" className="sr-only">Search user ID</label><input id="user-search" name="search" defaultValue={params.search} placeholder="Search by user ID" className="min-h-12 flex-1 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4"/><button className="min-h-12 rounded-xl bg-[var(--color-primary)] px-5 text-sm font-semibold text-[var(--color-on-primary)]">Search</button>{params.search ? <Link className="inline-flex min-h-12 items-center justify-center rounded-xl border border-[var(--color-border-strong)] px-5 text-sm font-semibold" href="/users">Clear</Link> : null}</form>
    <section aria-labelledby="users-heading" className="mt-6"><h2 id="users-heading" className="sr-only">User results</h2>{page.items.length === 0 ? <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-6"><h3 className="m-0 text-lg font-semibold">No users found</h3><p className="mt-2 mb-0 text-[var(--color-text-secondary)]">Try a different account reference.</p></div> : <div className="overflow-x-auto rounded-2xl border border-[var(--color-border-default)]"><table className="w-full min-w-3xl border-collapse text-left"><thead className="bg-[var(--color-surface-secondary)] text-sm text-[var(--color-text-secondary)]"><tr><th className="p-4">User</th><th className="p-4">Status</th><th className="p-4">Role</th><th className="p-4">Created</th><th className="p-4"><span className="sr-only">Open</span></th></tr></thead><tbody>{page.items.map((user) => <tr key={user.id} className="border-t border-[var(--color-border-default)]"><td className="p-4"><p className="m-0 font-semibold">{accountLabel(user.roles)}</p><p className="mt-1 mb-0 font-mono text-xs text-[var(--color-text-muted)]" title={user.id}>#{shortId(user.id)}</p></td><td className="p-4"><StatusBadge status={user.status}/></td><td className="p-4 text-sm text-[var(--color-text-secondary)]">{user.roles.join(", ") || "No active role"}</td><td className="p-4 text-sm text-[var(--color-text-secondary)]">{new Date(user.createdAt).toLocaleDateString()}</td><td className="p-4"><Link className="font-semibold text-[var(--color-primary)]" href={`/users/${user.id}`}>View details</Link></td></tr>)}</tbody></table></div>}
    {page.nextCursor ? <Link className="mt-5 inline-flex min-h-11 items-center rounded-xl border border-[var(--color-border-strong)] px-4 font-semibold" href={{ pathname: "/users", query: { search: params.search, cursor: page.nextCursor } }}>Next page</Link> : null}</section>
  </AdminShell>;
}
