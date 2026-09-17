import type { AppEnvironment } from "@/config/env";
import { logoutAction } from "@/auth/actions";
import type { StaffRole } from "@/auth/types";
import Link from "next/link";

const navigation = [
  { label: "Overview Dashboard", href: "/", icon: "dashboard", roles: null },
  { label: "Provider KYC Verification", href: "/providers", icon: "verified_user", roles: ["provider_reviewer", "operations_administrator", "auditor"] },
  { label: "Live Dispatches & Radar", href: "/bookings", icon: "fmd_good", roles: ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"] },
  { label: "Complaints & Escrow", href: "/support", icon: "payments", roles: ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"] },
  { label: "Trust & Safety Moderation", href: "/trust", icon: "gavel", roles: ["trust_safety_reviewer", "operations_administrator"] },
  { label: "Categories & Pricing", href: "/services", icon: "tune", roles: ["service_catalog_manager", "operations_administrator", "auditor"] },
] as const;

export function AdminShell({ environment, roles, current = "Overview Dashboard", children }: { environment: AppEnvironment; roles: readonly StaffRole[]; current?: string; children?: React.ReactNode }) {
  const visibleNavigation = navigation.filter((item) => item.roles === null || item.roles.some((role) => roles.includes(role)));
  
  return (
    <div className="bg-surface font-body-md text-body-md text-on-surface antialiased">
      <aside className="fixed left-0 top-0 h-full w-72 bg-surface-container-lowest border-r border-outline-variant/30 z-50 flex flex-col justify-between">
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
            <div className="px-space-sm py-space-xs font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-semibold">
              Operations Engine
            </div>
          </div>
          <nav className="flex flex-col gap-space-xs px-space-md">
            {visibleNavigation.map((item) => {
              const isActive = current === item.label;
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
              <span className="font-label-sm text-label-sm font-semibold uppercase text-on-surface-variant">Dispatch Node</span>
              <span className="font-label-sm text-label-sm text-primary font-bold">ONLINE</span>
            </div>
            <div className="font-data-mono text-data-mono text-on-surface-variant flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-primary-container"></span>
              {environment}-cluster-04
            </div>
          </div>
        </div>
      </aside>

      <div className="pl-72">
        <header className="fixed top-0 left-72 right-0 h-16 bg-surface-container-lowest/95 backdrop-blur-md border-b border-outline-variant/30 z-40 px-space-lg flex items-center justify-between">
          <div className="flex items-center gap-space-lg">
            <div className="relative w-80">
              <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-[18px]">search</span>
              <input
                className="w-full pl-9 pr-4 py-1.5 rounded-lg bg-surface border border-outline-variant/40 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant/70 focus:outline-none focus:border-primary"
                placeholder="Search job ID, tech license, client phone..."
                type="text"
              />
            </div>
          </div>
          <div className="flex items-center gap-space-md">
            <button className="relative p-1.5 rounded-lg text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface transition-colors">
              <span className="material-symbols-outlined text-[22px]">notifications</span>
            </button>
            <div className="flex items-center gap-space-sm pl-space-sm border-l border-outline-variant/30">
              <div className="text-right hidden sm:block">
                <span className="block font-label-md text-label-md font-semibold text-on-surface leading-tight">Chief Dispatcher</span>
                <span className="block font-label-sm text-label-sm text-on-surface-variant leading-none">{roles[0]?.replace('_', ' ') || 'Superadmin'}</span>
              </div>
              <img
                alt="Profile"
                className="w-8 h-8 rounded-full object-cover ring-1 ring-outline-variant/40"
                src="https://lh3.googleusercontent.com/aida/AEtjO1UHetTjpd4BB1e8njLlIDDmUsYV1qxX9ZC_wim9sHsXYmSrYRkJpnyD1IHW75IXxc9pB2kik0nzNC98TRCklpEgiq7TkSpL4ITZqzFt8uLi5EyWXYQq9m4a8YI9wZ3o6xvQSkDtb6AI5-x28GAADr5cRCtuuSX9N5FrvCQ7MBueDjttVq6CBcCdMU6PRAQsRnz78gBoZeg_WCxKbdy42V0Um4AxVfE0kNiMNfOiHfuES63iQSWWA34hjob7XGOL3mAbPdCfF9El6g"
              />
            </div>
          </div>
        </header>

        <main className="w-full pt-16 bg-surface min-h-screen">
          {children}
        </main>
      </div>
    </div>
  );
}
