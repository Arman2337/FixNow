import type { AppEnvironment } from "@/config/env";
import { logoutAction } from "@/auth/actions";
import type { StaffRole } from "@/auth/types";
import Image from "next/image";
import Link from "next/link";

const navigation = [
  { label: "Overview Dashboard", href: "/", icon: "dashboard", roles: null },
  { label: "Providers & KYC Verification", href: "/providers", icon: "verified_user", roles: ["provider_reviewer", "operations_administrator", "auditor"] },
  { label: "Live Dispatches & Radar", href: "/bookings", icon: "fmd_good", roles: ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"] },
  { label: "Complaints & Escrow", href: "/support", icon: "payments", roles: ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"] },
  { label: "Guarantee Claims", href: "/guarantees", icon: "verified", roles: ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"] },
  { label: "Trust & Safety Moderation", href: "/trust", icon: "gavel", roles: ["trust_safety_reviewer", "operations_administrator"] },
  { label: "Categories & Pricing", href: "/services", icon: "tune", roles: ["service_catalog_manager", "operations_administrator", "auditor"] },
] as const;

export function AdminShell({ environment, roles, current = "Overview Dashboard", children }: { environment: AppEnvironment; roles: readonly StaffRole[]; current?: string; children?: React.ReactNode }) {
  const visibleNavigation = navigation.filter((item) => item.roles === null || item.roles.some((role) => roles.includes(role)));
  const activeLabel = current === "Bookings" ? "Live Dispatches & Radar" : current === "Trust & Safety" ? "Trust & Safety Moderation" : current;

  return (
    <div className="bg-surface font-body-md text-body-md text-on-surface antialiased">
      <aside className="fixed left-0 top-0 hidden h-full w-72 bg-surface-container-lowest border-r border-outline-variant/30 z-50 lg:flex lg:flex-col lg:justify-between">
        <div className="flex flex-col">
          <div className="h-16 px-space-lg flex items-center border-b border-outline-variant/30 gap-space-sm">
            <div className="w-9 h-9 rounded-lg bg-primary flex items-center justify-center text-on-primary shadow-sm">
              <span className="material-symbols-outlined text-[20px]">build_circle</span>
            </div>
            <div>
              <span className="font-headline-md text-headline-md font-bold tracking-tight text-on-surface">
                Fix<span className="text-primary">Now</span>
              </span>
              <span className="block font-label-sm text-label-sm uppercase tracking-widest text-on-surface-variant">Admin Portal</span>
            </div>
          </div>
        <div className="px-space-md py-space-sm">
          <div className="px-space-sm py-space-xs font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-semibold">Operations Engine</div>
          <p className="sr-only">Role-based access is active. The navigation shows {visibleNavigation.length} modules available to this role.</p>
        </div>
          <nav aria-label="Admin navigation" className="flex flex-col gap-space-xs px-space-md">
            {visibleNavigation.map((item) => {
              const isActive = activeLabel === item.label;
              return (
                <Link
                  key={item.label}
                  href={item.href}
                  aria-current={isActive ? "page" : undefined}
                  className={`flex items-center justify-between px-space-md py-2.5 rounded-lg transition-colors ${
                    isActive
                      ? "bg-primary-container text-on-primary-container font-semibold shadow-sm"
                      : "text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface"
                  }`}
                >
                  <div className="flex items-center gap-space-sm">
                    <span className="material-symbols-outlined text-[20px]">{item.icon}</span>
                    <span>{item.label}</span>
                  </div>
                </Link>
              );
            })}
          </nav>
        </div>
        <div className="p-space-md border-t border-outline-variant/30">
          <div className="bg-surface-container-low p-space-md rounded-xl border border-outline-variant/20 flex flex-col gap-space-xs">
            <div className="flex items-center justify-between">
              <span className="font-label-sm text-label-sm font-semibold uppercase text-on-surface-variant">Environment</span>
              <span className="font-label-sm text-label-sm text-primary font-bold">Configured</span>
            </div>
            <div className="font-data-mono text-data-mono text-on-surface-variant">
              {environment}
            </div>
          </div>
        </div>
      </aside>

      <div className="lg:pl-72">
        <header className="fixed top-0 left-0 right-0 h-16 bg-surface-container-lowest/95 backdrop-blur-md border-b border-outline-variant/30 z-40 px-space-lg lg:pl-space-lg flex items-center justify-between gap-4">
          <div className="flex items-center gap-space-lg min-w-0">
            <details className="relative lg:hidden">
              <summary className="flex h-11 w-11 cursor-pointer list-none items-center justify-center rounded-lg border border-outline-variant/40 text-on-surface" aria-label="Open admin navigation">
                <span className="material-symbols-outlined">menu</span>
              </summary>
              <nav aria-label="Mobile admin navigation" className="absolute left-0 top-14 z-50 w-72 rounded-xl border border-outline-variant/40 bg-surface-container-lowest p-3 shadow-xl">
                {visibleNavigation.map((item) => (
                  <Link
                    key={item.label}
                    href={item.href}
                    className="flex min-h-11 items-center gap-space-sm rounded-lg px-3 text-label-md text-on-surface hover:bg-surface-container"
                    aria-current={activeLabel === item.label ? "page" : undefined}
                  >
                    <span className="material-symbols-outlined text-[20px]">{item.icon}</span>
                    <span>{item.label}</span>
                  </Link>
                ))}
              </nav>
            </details>
              <form action="/search" role="search" className="relative w-full max-w-80">
                <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-[18px]">search</span>
                <input
                  name="q"
                  className="w-full pl-9 pr-4 py-1.5 rounded-lg bg-surface border border-outline-variant/40 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant/70 focus:outline-none focus:border-primary"
                  placeholder="Search job ID, tech license, client phone..."
                  type="search"
                  aria-label="Search bookings, providers, complaints and users"
                />
              </form>
          </div>
          <div className="flex items-center gap-space-md">
            <Link href="/support" aria-label="Open support notifications" className="relative flex h-11 w-11 items-center justify-center rounded-lg text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface transition-colors">
              <span className="material-symbols-outlined text-[22px]">notifications</span>
            </Link>
            <div className="flex items-center gap-space-sm pl-space-sm border-l border-outline-variant/30">
              <div className="text-right hidden sm:block">
                <span className="block font-label-md text-label-md font-semibold text-on-surface leading-tight">Chief Dispatcher</span>
                <span className="block font-label-sm text-label-sm text-on-surface-variant leading-none">{roles[0]?.replace('_', ' ') || 'Superadmin'}</span>
              </div>
              <Image
                alt="Profile"
                className="h-8 w-8 rounded-full object-cover ring-1 ring-outline-variant/40"
                height={32}
                width={32}
                src="https://lh3.googleusercontent.com/aida/AEtjO1UHetTjpd4BB1e8njLlIDDmUsYV1qxX9ZC_wim9sHsXYmSrYRkJpnyD1IHW75IXxc9pB2kik0nzNC98TRCklpEgiq7TkSpL4ITZqzFt8uLi5EyWXYQq9m4a8YI9wZ3o6xvQSkDtb6AI5-x28GAADr5cRCtuuSX9N5FrvCQ7MBueDjttVq6CBcCdMU6PRAQsRnz78gBoZeg_WCxKbdy42V0Um4AxVfE0kNiMNfOiHfuES63iQSWWA34hjob7XGOL3mAbPdCfF9El6g"
              />
              <form action={logoutAction} className="hidden sm:block">
                <button type="submit" className="rounded-lg px-2 py-1 text-label-sm text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface">
                  Sign out
                </button>
              </form>
            </div>
          </div>
        </header>

        <a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:rounded-lg focus:bg-surface-container-lowest focus:px-4 focus:py-3 focus:text-on-surface">Skip to main content</a>
        <main id="main-content" className="w-full pt-16 bg-surface min-h-screen">
          {children}
        </main>
      </div>
    </div>
  );
}
