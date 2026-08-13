import { logoutAction } from "@/auth/actions";

export default function UnauthorizedPage() {
  return <main className="grid min-h-screen place-items-center px-4"><section className="max-w-lg rounded-3xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-8"><p className="m-0 text-sm font-semibold text-[var(--color-warning)]">Access restricted</p><h1 className="mt-2 text-3xl font-bold">You do not have access to this workspace</h1><p className="text-[var(--color-text-secondary)]">Your identity is valid, but no current staff permission allows this admin session. Contact an access administrator if this is unexpected.</p><form action={logoutAction}><button className="mt-4 min-h-12 rounded-xl bg-[var(--color-primary)] px-5 text-sm font-semibold text-[var(--color-on-primary)]">Return to sign in</button></form></section></main>;
}
