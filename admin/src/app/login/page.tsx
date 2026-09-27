import { LoginForm } from "@/auth/login-form";
import { getSession } from "@/auth/session";
import { redirect } from "next/navigation";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ reason?: string }> }) {
  const session = await getSession();
  if (session.state === "authenticated") redirect("/");
  const { reason } = await searchParams;
  const expired = reason === "expired" || session.state === "expired";

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md items-center justify-center p-space-lg">
      <div className="relative flex w-full flex-col overflow-hidden rounded-xl bg-surface-container-lowest p-space-lg shadow-xl md:p-space-xl">
        <div className="absolute -right-24 -top-24 h-64 w-64 rounded-full bg-primary/10 blur-3xl" aria-hidden="true" />
        <div className="relative z-10 flex flex-col items-center text-center">
          <div className="mb-space-sm flex h-16 w-16 items-center justify-center rounded-xl bg-surface-container shadow-sm" aria-hidden="true">
            <span className="material-symbols-outlined text-4xl text-primary">build_circle</span>
          </div>
          <div className="mb-space-xs inline-flex items-center gap-1.5 rounded-full bg-surface-container-high px-2.5 py-1 font-label-sm text-label-sm text-on-surface-variant">
            <span className="h-1.5 w-1.5 rounded-full bg-primary" aria-hidden="true" />
            <span>Authorized staff workspace</span>
          </div>
          <h1 className="font-headline-md text-headline-md text-on-surface tracking-tight">FixNow Admin Portal</h1>
          <p className="mt-1 mb-0 max-w-xs text-sm leading-snug text-on-surface-variant">Sign in with your staff account to access the operations assigned to your role.</p>
        </div>

        <LoginForm expired={expired} />

        <div className="relative z-10 mt-space-md text-center">
          <a className="inline-flex items-center gap-1 text-xs text-on-surface-variant transition-colors hover:text-primary" href="mailto:sec-ops@fixnow.internal">
            <span className="material-symbols-outlined text-[14px]" aria-hidden="true">contact_support</span>
            <span>Trouble signing in? Contact IT Security Operations Desk</span>
          </a>
        </div>
      </div>
    </main>
  );
}
