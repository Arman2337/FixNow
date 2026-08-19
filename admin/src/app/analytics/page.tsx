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
      <header className="border-b border-[var(--color-border-default)] pb-6">
        <p className="m-0 text-sm font-semibold text-[var(--color-primary)]">Operations</p>
        <h1 className="mt-2 mb-0 text-3xl font-semibold tracking-tight">Platform Analytics</h1>
        <p className="mt-2 text-[var(--color-text-muted)]">Real-time operational metrics for bookings, providers, and emergencies.</p>
      </header>

      <div className="mt-8 grid gap-8">
        
        {/* Bookings */}
        <section aria-labelledby="bookings-heading">
          <h2 id="bookings-heading" className="text-xl font-semibold mb-4">Booking Operations</h2>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Total Bookings</p>
              <p className="mt-2 text-3xl font-semibold">{analytics.bookings.total}</p>
            </div>
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Pending / Active</p>
              <p className="mt-2 text-3xl font-semibold text-yellow-600 dark:text-yellow-400">{analytics.bookings.pending}</p>
            </div>
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Completed</p>
              <p className="mt-2 text-3xl font-semibold text-green-600 dark:text-green-400">{analytics.bookings.completed}</p>
            </div>
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Cancelled</p>
              <p className="mt-2 text-3xl font-semibold text-red-600 dark:text-red-400">{analytics.bookings.cancelled}</p>
            </div>
          </div>
        </section>

        {/* Providers */}
        <section aria-labelledby="providers-heading">
          <h2 id="providers-heading" className="text-xl font-semibold mb-4">Provider Ecosystem</h2>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Total Providers</p>
              <p className="mt-2 text-3xl font-semibold">{analytics.providers.total}</p>
            </div>
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Active Now</p>
              <p className="mt-2 text-3xl font-semibold text-green-600 dark:text-green-400">{analytics.providers.active}</p>
            </div>
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Fully Verified</p>
              <p className="mt-2 text-3xl font-semibold text-blue-600 dark:text-blue-400">{analytics.providers.verified}</p>
            </div>
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
              <p className="text-sm text-[var(--color-text-muted)]">Pending Verification</p>
              <p className="mt-2 text-3xl font-semibold text-orange-600 dark:text-orange-400">{analytics.providers.pendingVerification}</p>
            </div>
          </div>
        </section>

        {/* Emergencies & Services */}
        <div className="grid gap-8 sm:grid-cols-2">
          <section aria-labelledby="emergencies-heading">
            <h2 id="emergencies-heading" className="text-xl font-semibold mb-4">Emergency Dispatch</h2>
            <div className="grid gap-4">
              <div className="rounded-2xl border border-[var(--color-border-strong)] bg-red-50 dark:bg-red-950/20 p-5">
                <p className="text-sm font-semibold text-red-700 dark:text-red-400">Active Emergency Requests</p>
                <p className="mt-2 text-4xl font-bold text-red-700 dark:text-red-400">{analytics.emergencies.activeRequests}</p>
              </div>
              <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
                <p className="text-sm text-[var(--color-text-muted)]">Historical Emergencies (All-time)</p>
                <p className="mt-2 text-2xl font-semibold">{analytics.emergencies.totalRequests}</p>
              </div>
            </div>
          </section>

          <section aria-labelledby="services-heading">
            <h2 id="services-heading" className="text-xl font-semibold mb-4">Top Services</h2>
            <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5 overflow-hidden">
              <ul className="m-0 p-0 grid gap-4 list-none">
                {analytics.services.topCategories.length > 0 ? (
                  analytics.services.topCategories.map((cat, i) => (
                    <li key={cat.id} className="flex items-center justify-between">
                      <span className="flex items-center gap-3">
                        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-[var(--color-surface-secondary)] text-xs font-semibold text-[var(--color-text-muted)]">
                          {i + 1}
                        </span>
                        <span className="font-medium">{cat.name}</span>
                      </span>
                      <span className="font-mono text-sm font-semibold">{cat.count}</span>
                    </li>
                  ))
                ) : (
                  <p className="text-sm text-[var(--color-text-muted)] text-center py-4">Not enough data to display.</p>
                )}
              </ul>
            </div>
          </section>
        </div>

      </div>
    </AdminShell>
  );
}
