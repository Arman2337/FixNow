import { LoginForm } from "@/auth/login-form";
import { refreshAction } from "@/auth/actions";
import { getSession } from "@/auth/session";
import { redirect } from "next/navigation";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ reason?: string }> }) {
  const session = await getSession();
  if (session.state === "authenticated") redirect("/");
  const { reason } = await searchParams;
  const expired = reason === "expired" || session.state === "expired";
  return (
    <main className="grid min-h-screen place-items-center px-4 py-10">
      <section aria-labelledby="login-title" className="w-full max-w-md rounded-3xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-6 sm:p-8">
        <div className="flex items-center gap-3"><span aria-hidden="true" className="grid size-10 place-items-center rounded-xl bg-[var(--color-primary)] font-bold text-[var(--color-on-primary)]">F</span><p className="m-0 text-lg font-semibold">FixNow Admin</p></div>
        <p className="mt-8 mb-0 text-sm font-semibold text-[var(--color-primary)]">Authorized staff only</p>
        <h1 id="login-title" className="mt-2 mb-0 text-3xl font-bold leading-10">Sign in</h1>
        <p className="mt-2 mb-0 text-[var(--color-text-secondary)]">Use your assigned staff credentials. Access remains limited by backend permissions.</p>
        {expired ? <div role="status" className="mt-6 rounded-xl border border-[var(--color-warning)] bg-[var(--color-warning-soft)] p-4"><p className="m-0 font-semibold">Your session expired</p><p className="mt-1 mb-0 text-sm text-[var(--color-text-secondary)]">Continue securely if your staff session is still valid, or sign in again.</p><form action={refreshAction}><button className="mt-3 min-h-11 rounded-xl border border-[var(--color-border-strong)] px-4 text-sm font-semibold">Continue session</button></form></div> : null}
        {reason === "signed-out" ? <p role="status" className="mt-6 rounded-xl bg-[var(--color-primary-soft)] p-3 text-sm">You have signed out securely.</p> : null}
        <LoginForm />
      </section>
    </main>
  );
}
