import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listBookings } from "@/features/operations/api";
import { StatusBadge } from "@/features/status-badge";

const statuses = ["", "REQUESTED", "ASSIGNED", "EN_ROUTE", "IN_PROGRESS", "COMPLETED", "CANCELLED"];

function formatScheduledAt(value: string | null) {
  if (!value) return "Not scheduled";
  return new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

export default async function BookingsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; status?: string; cursor?: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const params = await searchParams;
  const page = await requireManagementResult(await listBookings(params.search, params.status, params.cursor));
  const emergencyCount = page.items.filter(
    (booking) => booking.serviceCategoryId.toLowerCase().includes("emergency") || booking.description.toLowerCase().includes("emergency"),
  ).length;

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Live Dispatches & Radar">
      <div className="flex w-full flex-col">
        <div className="flex flex-col gap-space-lg p-space-lg lg:p-margin-desktop">
          <header className="flex flex-col justify-between gap-3 md:flex-row md:items-end">
            <div>
              <p className="m-0 text-xs font-bold uppercase tracking-wider text-primary">Dispatch queue</p>
              <h1 className="mt-1 text-3xl font-bold tracking-tight text-on-surface">Bookings and SOS radar</h1>
              <p className="mt-2 mb-0 text-sm text-on-surface-variant">Live records returned by the authorized management API.</p>
            </div>
            <div className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest px-4 py-3 text-sm text-on-surface">
              <span className="block text-xs uppercase tracking-wider text-on-surface-variant">Current result</span>
              <strong>{page.items.length} booking{page.items.length === 1 ? "" : "s"}</strong>
            </div>
          </header>

          <div className="flex flex-wrap items-center gap-2" aria-label="Booking status filters">
            <Link href="/bookings" className={`rounded-lg px-4 py-2 text-sm font-semibold ${!params.status ? "bg-primary text-on-primary" : "bg-surface-container-low text-on-surface-variant"}`}>
              All dispatches <span className="ml-1">{page.items.length}</span>
            </Link>
            {statuses.slice(1).map((status) => (
              <Link key={status} href={`/bookings?status=${status}`} className={`rounded-lg px-4 py-2 text-sm font-semibold ${params.status === status ? "bg-primary text-on-primary" : "bg-surface-container-low text-on-surface-variant"}`}>
                {status.replaceAll("_", " ")} <span className="ml-1">{page.items.filter((booking) => booking.status === status).length}</span>
              </Link>
            ))}
          </div>

          <form role="search" aria-label="Filter bookings" className="flex flex-wrap items-center gap-2 rounded-xl border border-outline-variant/30 bg-surface-container-low p-2">
            <div className="flex min-w-56 flex-1 items-center rounded-lg border border-outline-variant/50 bg-surface px-3 focus-within:border-primary">
              <span className="material-symbols-outlined text-on-surface-variant" aria-hidden="true">search</span>
              <input id="booking-search" name="search" defaultValue={params.search} placeholder="Search booking ID, category or description" className="w-full border-0 bg-transparent px-2 py-2 text-sm text-on-surface outline-none" />
            </div>
            <select id="booking-status" name="status" defaultValue={params.status ?? ""} className="rounded-lg border border-outline-variant/50 bg-surface px-3 py-2 text-sm text-on-surface">
              {statuses.map((status) => <option key={status} value={status}>{status ? status.replaceAll("_", " ") : "All statuses"}</option>)}
            </select>
            <button type="submit" className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-on-primary">Filter</button>
            <Link href="/bookings" className="rounded-lg border border-outline-variant/30 bg-surface-container px-4 py-2 text-center text-sm font-semibold text-on-surface">Clear</Link>
          </form>

          {emergencyCount > 0 ? (
            <div role="status" className="flex items-center gap-3 rounded-xl border border-error/30 bg-error-container/20 p-4 text-sm text-on-surface">
              <span className="material-symbols-outlined text-error" aria-hidden="true">crisis_alert</span>
              <span><strong>{emergencyCount} emergency record{emergencyCount === 1 ? "" : "s"}</strong> appear in this filtered result. Review the records below before taking action.</span>
            </div>
          ) : null}

          <section aria-labelledby="booking-table-heading" className="overflow-hidden rounded-2xl border border-outline-variant/30 bg-surface-container-lowest shadow-sm">
            <div className="flex items-center justify-between gap-3 border-b border-outline-variant/30 bg-surface-container-low/40 p-space-md">
              <h2 id="booking-table-heading" className="m-0 text-lg font-bold text-on-surface">Authorized booking records</h2>
              <span className="text-xs text-on-surface-variant">{page.nextCursor ? "More records available" : "End of current result"}</span>
            </div>
            {page.items.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[760px] text-left text-sm">
                  <thead className="bg-surface-container-low text-xs uppercase tracking-wider text-on-surface-variant">
                    <tr>
                      <th scope="col" className="px-4 py-3">Booking</th>
                      <th scope="col" className="px-4 py-3">Service</th>
                      <th scope="col" className="px-4 py-3">Customer</th>
                      <th scope="col" className="px-4 py-3">Provider</th>
                      <th scope="col" className="px-4 py-3">Scheduled</th>
                      <th scope="col" className="px-4 py-3">Status</th>
                      <th scope="col" className="px-4 py-3 text-right">Version</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-outline-variant/20">
                    {page.items.map((booking) => (
                      <tr key={booking.id} className="hover:bg-surface-container/50">
                        <td className="px-4 py-3 font-mono text-xs font-semibold text-on-surface">{booking.id}</td>
                        <td className="max-w-56 px-4 py-3"><span className="block truncate text-on-surface">{booking.serviceCategoryId}</span><span className="block max-w-56 truncate text-xs text-on-surface-variant">{booking.description}</span></td>
                        <td className="px-4 py-3 font-mono text-xs text-on-surface-variant">{booking.customerId}</td>
                        <td className="px-4 py-3 font-mono text-xs text-on-surface-variant">{booking.providerId ?? "Unassigned"}</td>
                        <td className="px-4 py-3 text-on-surface-variant">{formatScheduledAt(booking.scheduledAt)}</td>
                        <td className="px-4 py-3"><StatusBadge status={booking.status} /></td>
                        <td className="px-4 py-3 text-right font-mono text-xs text-on-surface-variant">{booking.version}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="p-8 text-center">
                <span className="material-symbols-outlined text-4xl text-on-surface-variant" aria-hidden="true">event_busy</span>
                <h3 className="mt-3 mb-1 text-lg font-bold text-on-surface">No bookings match these filters</h3>
                <p className="m-0 text-sm text-on-surface-variant">Clear the filters or choose another status.</p>
              </div>
            )}
          </section>
        </div>
      </div>
    </AdminShell>
  );
}
