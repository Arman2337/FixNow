import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { getAnalytics } from "@/features/operations/api";
import { redirect } from "next/navigation";

function formatGeneratedAt(value: string) {
  return new Intl.DateTimeFormat("en-IN", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function Home() {
  const result = await getSession();
  if (result.state !== "authenticated") {
    if (result.state === "anonymous") redirect("/login");
    if (result.state === "expired") redirect("/login?reason=expired");
    redirect("/unauthorized");
  }

  const canViewAnalytics = result.session.roles.some(
    (role) => role === "operations_administrator" || role === "auditor",
  );
  const analytics = canViewAnalytics
    ? await requireManagementResult(await getAnalytics())
    : null;

  if (!analytics) {
    return (
      <AdminShell environment={env.appEnvironment} roles={result.session.roles}>
        <section aria-labelledby="access-heading" className="mt-8 rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-6 shadow-sm">
          <p className="m-0 text-xs font-bold uppercase tracking-wider text-primary">Your Staff Access</p>
          <h2 id="access-heading" className="mt-2 mb-0 text-xl font-bold text-on-surface">Choose an operation from the navigation</h2>
          <p className="mt-2 mb-0 max-w-2xl text-sm text-on-surface-variant">Your role does not include platform-wide analytics. Use the navigation modules to manage the operations assigned to you.</p>
        </section>
      </AdminShell>
    );
  }

  const metrics = [
    { label: "Bookings pending", value: analytics.bookings.pending, icon: "pending_actions" },
    { label: "Active providers", value: analytics.providers.active, icon: "engineering" },
    { label: "Completed bookings", value: analytics.bookings.completed, icon: "task_alt" },
    { label: "Active emergencies", value: analytics.emergencies.activeRequests, icon: "crisis_alert" },
  ];

  return (
    <AdminShell environment={env.appEnvironment} roles={result.session.roles} current="Overview Dashboard">
      <div className="flex w-full flex-col">
        <div className="flex flex-col gap-space-lg p-space-lg lg:p-margin-desktop">
          <header className="flex flex-col gap-3">
            <p className="m-0 text-xs font-bold uppercase tracking-wider text-primary">{env.appEnvironment} operational grid</p>
            <div className="flex flex-col justify-between gap-3 lg:flex-row lg:items-end">
              <div>
                <h1 className="mt-0 text-3xl font-bold tracking-tight text-on-surface">Live operations overview</h1>
                <p className="mt-2 mb-0 text-sm text-on-surface-variant">Read-only platform metrics for the current reporting window.</p>
              </div>
              <p className="m-0 text-xs text-on-surface-variant">Generated {formatGeneratedAt(analytics.generatedAt)}</p>
            </div>
          </header>

          <section aria-labelledby="metrics-heading">
            <h2 id="metrics-heading" className="sr-only">Key metrics</h2>
            <div className="grid grid-cols-1 gap-space-md sm:grid-cols-2 xl:grid-cols-4">
              {metrics.map((metric) => (
                <div key={metric.label} className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
                  <div className="flex items-center justify-between gap-3">
                    <span className="text-xs font-semibold uppercase tracking-wider text-on-surface-variant">{metric.label}</span>
                    <span className="material-symbols-outlined text-primary" aria-hidden="true">{metric.icon}</span>
                  </div>
                  <strong className="mt-3 block text-3xl text-on-surface">{metric.value}</strong>
                </div>
              ))}
            </div>
          </section>

          <section aria-labelledby="trust-heading" className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
            <div className="flex flex-col justify-between gap-4 md:flex-row md:items-center">
              <div>
                <h2 id="trust-heading" className="m-0 text-lg font-bold text-on-surface">Trust and service signals</h2>
                <p className="mt-1 mb-0 text-sm text-on-surface-variant">The service exposes only measured, authorized values here.</p>
              </div>
              <div className="grid grid-cols-2 gap-3 text-sm md:min-w-[28rem]">
                <div className="rounded-xl bg-surface-container p-3">
                  <span className="block text-xs text-on-surface-variant">Average accept time</span>
                  <strong className="mt-1 block text-on-surface">{analytics.trust.averageAcceptMinutes === null ? "Not available" : `${analytics.trust.averageAcceptMinutes} min`}</strong>
                </div>
                <div className="rounded-xl bg-surface-container p-3">
                  <span className="block text-xs text-on-surface-variant">Verified providers</span>
                  <strong className="mt-1 block text-on-surface">{analytics.providers.verified}</strong>
                </div>
              </div>
            </div>
          </section>

          <section aria-labelledby="categories-heading" className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-md shadow-sm">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 id="categories-heading" className="m-0 text-lg font-bold text-on-surface">Top service categories</h2>
                <p className="mt-1 mb-0 text-sm text-on-surface-variant">Counts returned by the analytics service.</p>
              </div>
              <span className="text-sm text-on-surface-variant">{analytics.services.topCategories.length} categories</span>
            </div>
            {analytics.services.topCategories.length > 0 ? (
              <div className="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                {analytics.services.topCategories.map((category) => (
                  <div key={category.id} className="flex items-center justify-between rounded-xl border border-outline-variant/20 px-3 py-2">
                    <span className="text-sm text-on-surface">{category.name}</span>
                    <strong className="text-sm text-on-surface">{category.count}</strong>
                  </div>
                ))}
              </div>
            ) : (
              <p className="mt-4 mb-0 rounded-xl bg-surface-container p-4 text-sm text-on-surface-variant">No service category activity was reported for this window.</p>
            )}
          </section>
        </div>
      </div>
    </AdminShell>
  );
}
