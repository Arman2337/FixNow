import type { AppEnvironment } from "@/config/env";
import { logoutAction } from "@/auth/actions";
import type { StaffRole } from "@/auth/types";
import Link from "next/link";

const navigation = [
  { label: "Overview", href: "/", roles: null },
  { label: "Users", href: "/users", roles: ["support_agent", "operations_administrator", "security_administrator", "auditor"] },
  { label: "Providers", href: "/providers", roles: ["provider_reviewer", "operations_administrator", "auditor"] },
  { label: "Services", href: "/services", roles: ["service_catalog_manager", "operations_administrator", "auditor"] },
  { label: "Bookings", href: "/bookings", roles: ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"] },
  { label: "Support", href: "/support", roles: ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"] },
  { label: "Access", href: "", roles: ["security_administrator", "auditor"] },
] as const;

export function AdminShell({ environment, roles, current = "Overview", children }: { environment: AppEnvironment; roles: readonly StaffRole[]; current?: string; children?: React.ReactNode }) {
  const visibleNavigation = navigation.filter((item) => item.roles === null || item.roles.some((role) => roles.includes(role)));
  return (
    <div className="min-h-screen bg-[var(--color-background-primary)] lg:grid lg:grid-cols-[17rem_1fr]">
      <aside className="border-b border-[var(--color-border-default)] bg-[var(--color-background-secondary)] px-4 py-5 lg:min-h-screen lg:border-r lg:border-b-0 lg:px-6">
        <div className="flex items-center gap-3">
          <span aria-hidden="true" className="grid size-10 place-items-center rounded-xl bg-[var(--color-primary)] font-bold text-[var(--color-on-primary)]">F</span>
          <div>
            <p className="m-0 text-lg font-semibold leading-6">FixNow</p>
            <p className="m-0 text-xs font-medium uppercase tracking-[0.12em] text-[var(--color-text-muted)]">Admin workspace</p>
          </div>
        </div>
        <nav aria-label="Admin navigation" className="mt-6">
          <ul className="m-0 flex list-none gap-2 overflow-x-auto p-0 lg:flex-col">
            {visibleNavigation.map((item) => (
              <li key={item.label}>
                {item.href ? <Link href={item.href} aria-current={current === item.label ? "page" : undefined} className={`flex min-h-12 items-center rounded-xl px-4 text-sm font-semibold whitespace-nowrap ${current === item.label ? "bg-[var(--color-primary-soft)] text-[var(--color-primary)]" : "text-[var(--color-text-secondary)]"}`}>{item.label}</Link> : <span aria-disabled="true" className="flex min-h-12 items-center rounded-xl px-4 text-sm font-semibold whitespace-nowrap text-[var(--color-text-muted)]">{item.label}</span>}
              </li>
            ))}
          </ul>
        </nav>
      </aside>

      <main id="main-content" className="px-4 py-8 sm:px-6 lg:px-10 lg:py-12">
        <div className="mx-auto max-w-5xl">
          {children ?? <><header className="flex flex-col gap-4 border-b border-[var(--color-border-default)] pb-6 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="m-0 text-sm font-semibold text-[var(--color-primary)]">Operations foundation</p>
              <h1 className="mt-2 mb-0 text-3xl font-bold leading-10 tracking-tight sm:text-[2.5rem] sm:leading-12">Admin overview</h1>
              <p className="mt-2 mb-0 max-w-2xl text-base text-[var(--color-text-secondary)]">The secure workspace foundation is ready. Operational tools will appear here only after their workflows and permissions are implemented.</p>
            </div>
            <div className="flex items-center gap-3"><span className="inline-flex min-h-8 w-fit items-center rounded-full border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-3 text-xs font-semibold capitalize text-[var(--color-text-secondary)]">{environment}</span><form action={logoutAction}><button className="min-h-11 rounded-xl border border-[var(--color-border-strong)] px-4 text-sm font-semibold">Sign out</button></form></div>
          </header>

          <section aria-labelledby="status-heading" className="mt-8 rounded-3xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5 sm:p-6">
            <div className="flex items-start gap-4">
              <span aria-hidden="true" className="mt-1 size-3 shrink-0 rounded-full bg-[var(--color-info)]" />
              <div>
                <h2 id="status-heading" className="m-0 text-xl font-semibold leading-7">Foundation status</h2>
                <p className="mt-2 mb-0 text-[var(--color-text-secondary)]">Authentication and administrative workflows are not enabled yet. This shell intentionally exposes no privileged data or inert primary actions.</p>
              </div>
            </div>
          </section></>}

          <section aria-labelledby="modules-heading" className="mt-8">
            <h2 id="modules-heading" className="m-0 text-xl font-semibold leading-7">Planned modules</h2>
            <div className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {["Identity and access", "Provider verification", "Booking operations"].map((module) => (
                <article key={module} className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
                  <p className="m-0 text-lg font-semibold">{module}</p>
                  <p className="mt-2 mb-0 text-sm text-[var(--color-text-muted)]">Not configured</p>
                </article>
              ))}
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
