import { logoutAction } from "@/auth/actions";

export default function UnauthorizedPage() {
  return (
    <main className="grid min-h-screen place-items-center bg-surface px-4">
      <section className="max-w-lg rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-8 shadow-sm text-center">
        <div className="mx-auto w-16 h-16 rounded-full bg-error-container text-on-error-container flex items-center justify-center mb-6">
          <span className="material-symbols-outlined text-3xl">gpp_bad</span>
        </div>
        <h1 className="font-headline-md text-headline-md font-bold text-on-surface">Access Restricted</h1>
        <p className="mt-4 font-body-md text-on-surface-variant leading-relaxed">
          Your identity is valid, but no current staff permission allows this admin session. Contact an access administrator if this is unexpected.
        </p>
        <form action={logoutAction} className="mt-8">
          <button className="w-full min-h-12 rounded-xl bg-primary hover:bg-primary-container transition-colors text-on-primary font-label-md text-label-md font-bold shadow-sm flex items-center justify-center gap-2">
            <span className="material-symbols-outlined text-[18px]">logout</span>
            Return to Sign In
          </button>
        </form>
      </section>
    </main>
  );
}
