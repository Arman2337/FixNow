import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { getAnalytics } from "@/features/operations/api";

export default async function AnalyticsPage() {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const hasAccess = session.session.roles.some((role) => role === "operations_administrator" || role === "auditor");
  if (!hasAccess) redirect("/unauthorized");

  const response = await getAnalytics();
  const analytics = await requireManagementResult(response);

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Analytics">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">Platform Telemetry</span>
                <span className="w-1 h-1 rounded-full bg-outline"></span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Live Operational Snapshot</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Platform Analytics</h1>
            </div>
            <div className="px-3 py-1.5 rounded-lg bg-surface-container-low border border-outline-variant/30 flex items-center gap-2 shadow-sm">
              <span className="w-2 h-2 rounded-full bg-primary animate-pulse"></span>
              <span className="font-data-mono text-label-sm text-on-surface-variant">Last synced: {new Date(analytics.generatedAt).toLocaleTimeString()}</span>
            </div>
          </div>

          <div className="grid gap-space-lg">
            
            {/* Bookings */}
            <section aria-labelledby="bookings-heading">
              <h2 id="bookings-heading" className="font-headline-sm text-headline-sm font-bold text-on-surface mb-space-sm flex items-center gap-2">
                <span className="material-symbols-outlined text-primary">calendar_month</span> Booking Operations
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-space-md">
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Total Bookings</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-on-surface">{analytics.bookings.total}</p>
                </div>
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Pending / Active</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-tertiary">{analytics.bookings.pending}</p>
                </div>
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Completed</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-primary">{analytics.bookings.completed}</p>
                </div>
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Cancelled</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-error">{analytics.bookings.cancelled}</p>
                </div>
              </div>
            </section>

            {/* Providers */}
            <section aria-labelledby="providers-heading">
              <h2 id="providers-heading" className="font-headline-sm text-headline-sm font-bold text-on-surface mb-space-sm flex items-center gap-2">
                <span className="material-symbols-outlined text-primary">engineering</span> Provider Ecosystem
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-space-md">
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Total Providers</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-on-surface">{analytics.providers.total}</p>
                </div>
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Active Now</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-primary">{analytics.providers.active}</p>
                </div>
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Fully Verified</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-on-surface">{analytics.providers.verified}</p>
                </div>
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <p className="font-label-sm text-label-sm uppercase text-secondary">Pending Verification</p>
                  <p className="mt-2 font-headline-lg text-headline-lg font-bold text-tertiary">{analytics.providers.pendingVerification}</p>
                </div>
              </div>
            </section>

            {/* Priority categories and services */}
            <div className="grid gap-space-lg lg:grid-cols-2">
              <section aria-labelledby="priority-categories-heading">
                <h2 id="priority-categories-heading" className="font-headline-sm text-headline-sm font-bold text-on-surface mb-space-sm flex items-center gap-2">
                  <span className="material-symbols-outlined text-error">emergency</span> Priority Dispatches
                </h2>
                <div className="grid gap-space-md">
                  <div className="rounded-2xl border border-error/30 bg-error-container/20 p-space-lg shadow-sm">
                    <p className="font-label-md text-label-md uppercase font-bold text-error">Active SOS / Emergency Requests</p>
                    <p className="mt-2 text-6xl font-black text-error">{analytics.emergencies.activeRequests}</p>
                  </div>
                  <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm flex items-center justify-between">
                    <p className="font-label-sm text-label-sm uppercase text-secondary">Priority-Category Lifetime Total</p>
                    <p className="font-headline-md text-headline-md font-bold text-on-surface">{analytics.emergencies.totalRequests}</p>
                  </div>
                </div>
              </section>

              <section aria-labelledby="services-heading">
                <h2 id="services-heading" className="font-headline-sm text-headline-sm font-bold text-on-surface mb-space-sm flex items-center gap-2">
                  <span className="material-symbols-outlined text-primary">bar_chart</span> Top Services Requested
                </h2>
                <div className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm overflow-hidden h-full">
                  <div className="flex flex-col gap-3">
                    {analytics.services.topCategories.length > 0 ? (
                      analytics.services.topCategories.map((cat, i) => (
                        <div key={cat.id} className="flex items-center justify-between p-3 rounded-xl bg-surface-container-low border border-outline-variant/30">
                          <div className="flex items-center gap-3">
                            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-surface-container-high font-bold text-on-surface">
                              {i + 1}
                            </span>
                            <span className="font-label-md text-label-md font-bold text-on-surface">{cat.name.replace(/_/g, " ")}</span>
                          </div>
                          <span className="font-data-mono text-label-md font-bold text-primary px-3 py-1 bg-primary/10 rounded-md">{cat.count}</span>
                        </div>
                      ))
                    ) : (
                      <p className="text-sm font-body-sm text-on-surface-variant text-center py-8">Not enough data to display service rankings.</p>
                    )}
                  </div>
                </div>
              </section>
            </div>

          </div>
        </div>
      </div>
    </AdminShell>
  );
}
