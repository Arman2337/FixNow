import Link from "next/link";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { getUser } from "@/features/users/api";
import { requireManagementResult } from "@/features/management-api";
import { StatusBadge } from "@/features/status-badge";
import { redirect } from "next/navigation";

export default async function UserDetailPage({ params }: { params: Promise<{ userId: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const { userId } = await params;
  const user = await requireManagementResult(await getUser(userId));
  return <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Users"><Link href="/users" className="text-sm font-semibold text-[var(--color-primary)]">← Users</Link><header className="mt-5 border-b border-[var(--color-border-default)] pb-6"><h1 className="m-0 text-3xl font-bold">User details</h1><p className="mt-2 mb-0 text-[var(--color-text-secondary)]">Only operationally necessary account metadata is shown.</p></header><dl className="mt-6 grid gap-4 rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-6 sm:grid-cols-2"><div><dt className="text-sm text-[var(--color-text-muted)]">Opaque user ID</dt><dd className="mt-1 break-all font-mono text-sm">{user.id}</dd></div><div><dt className="text-sm text-[var(--color-text-muted)]">Status</dt><dd className="mt-1"><StatusBadge status={user.status}/></dd></div><div><dt className="text-sm text-[var(--color-text-muted)]">Current roles</dt><dd className="mt-1">{user.roles.join(", ") || "No active role"}</dd></div><div><dt className="text-sm text-[var(--color-text-muted)]">Created</dt><dd className="mt-1">{new Date(user.createdAt).toLocaleString()}</dd></div></dl></AdminShell>;
}
