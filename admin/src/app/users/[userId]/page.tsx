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
  return <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Users"><Link href="/users" className="text-sm font-semibold text-[var(--color-primary)]">← Back to users</Link><header className="mt-5 flex flex-col gap-4 border-b border-[var(--color-border-default)] pb-6 sm:flex-row sm:items-start sm:justify-between"><div><p className="m-0 text-sm font-semibold uppercase tracking-[0.08em] text-[var(--color-primary)]">Account operations</p><h1 className="mt-2 mb-0 text-3xl font-bold">{accountLabel(user.roles)}</h1><p className="mt-2 mb-0 font-mono text-xs text-[var(--color-text-muted)]" title={user.id}>User #{shortId(user.id)}</p></div><StatusBadge status={user.status}/></header><section aria-labelledby="account-overview" className="mt-6 rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-6"><h2 id="account-overview" className="m-0 text-xl font-semibold">Account overview</h2><p className="mt-2 mb-0 text-[var(--color-text-secondary)]">Only operationally necessary account metadata is available here.</p><dl className="mt-5 grid gap-5 border-t border-[var(--color-border-default)] pt-5 sm:grid-cols-2"><div><dt className="text-sm text-[var(--color-text-muted)]">Account type</dt><dd className="mt-1 font-semibold">{accountLabel(user.roles)}</dd></div><div><dt className="text-sm text-[var(--color-text-muted)]">Roles</dt><dd className="mt-1">{user.roles.join(", ") || "No active role"}</dd></div><div><dt className="text-sm text-[var(--color-text-muted)]">Created</dt><dd className="mt-1">{new Date(user.createdAt).toLocaleString()}</dd></div><div><dt className="text-sm text-[var(--color-text-muted)]">Last updated</dt><dd className="mt-1">{new Date(user.updatedAt).toLocaleString()}</dd></div></dl></section><section aria-labelledby="account-reference" className="mt-6 rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5"><h2 id="account-reference" className="m-0 text-lg font-semibold">Account reference</h2><p className="mt-2 mb-0 font-mono text-sm text-[var(--color-text-secondary)]">#{shortId(user.id)}</p><details className="mt-3 text-sm text-[var(--color-text-muted)]"><summary className="cursor-pointer">Show full user ID</summary><p className="mt-2 mb-0 break-all font-mono text-xs">{user.id}</p></details></section></AdminShell>;
}
