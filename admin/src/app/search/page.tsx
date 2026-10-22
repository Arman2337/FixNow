import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listClaims } from "@/features/guarantees/api";
import { listBookings, listComplaints } from "@/features/operations/api";
import { listProviderApplications } from "@/features/providers/api";

import { hasPermission } from "@/auth/roles";

function textResult(label: string, value: string, href: string) {
  return { label, value, href };
}

export default async function SearchPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const query = (await searchParams).q?.trim() ?? "";
  const roles = session.session.roles;
  const results: { label: string; value: string; href: string }[] = [];

  if (query.length >= 2) {
    const searchTasks: Promise<void>[] = [];

    if (hasPermission(roles, "adminBookingsRead")) {
      searchTasks.push(
        (async () => {
          const bookings = await requireManagementResult(await listBookings(query));
          results.push(
            ...bookings.items.map((booking) =>
              textResult("Booking", `${booking.id} · ${booking.status} · ${booking.description}`, `/bookings?search=${encodeURIComponent(query)}`),
            ),
          );
        })(),
      );
    }

    if (hasPermission(roles, "adminProviderApplicationsRead")) {
      searchTasks.push(
        (async () => {
          const providers = await requireManagementResult(await listProviderApplications(query));
          results.push(
            ...providers.items.map((provider) =>
              textResult("Provider", `${provider.displayName ?? provider.id} · ${provider.status}`, `/providers/${provider.id}`),
            ),
          );
        })(),
      );
    }

    if (hasPermission(roles, "adminComplaintsRead")) {
      searchTasks.push(
        (async () => {
          const complaints = await requireManagementResult(await listComplaints(20, 0, undefined, query));
          results.push(
            ...complaints
              .map((complaint) =>
                textResult("Complaint", `${complaint.id} · ${complaint.status} · ${complaint.category}`, `/support/${complaint.id}`),
              ),
          );
        })(),
      );
    }

    if (hasPermission(roles, "adminGuaranteesRead")) {
      searchTasks.push(
        (async () => {
          const claims = await requireManagementResult(await listClaims(undefined, 20, 0, query));
          results.push(
            ...claims
              .map((claim) =>
                textResult("Guarantee claim", `${claim.id} · ${claim.status} · ${claim.description}`, `/guarantees/${claim.id}`),
              ),
          );
        })(),
      );
    }

    await Promise.all(searchTasks);
  }

  return (
    <AdminShell
      environment={env.appEnvironment}
      roles={roles}
      email={session.session.email}
      displayName={session.session.displayName}
      current="Search"
    >
      <div className="w-full p-space-lg lg:p-margin-desktop">
        <div className="mx-auto flex max-w-4xl flex-col gap-space-lg">
          <header>
            <p className="m-0 text-xs font-bold uppercase tracking-wider text-primary">Role-aware command search</p>
            <h1 className="mt-1 text-3xl font-bold tracking-tight text-on-surface">Search operations</h1>
            <p className="mt-2 mb-0 text-sm text-on-surface-variant">Showing up to 20 matches per record type your staff role can access. Continue in a queue to browse additional matches.</p>
          </header>
          <form action="/search" role="search" aria-label="Search operations" className="flex gap-2 rounded-xl border border-outline-variant/30 bg-surface-container-low p-2">
            <label className="sr-only" htmlFor="command-search">Search operations</label>
            <input id="command-search" name="q" defaultValue={query} placeholder="Booking, provider, complaint or claim" className="min-w-0 flex-1 rounded-lg border border-outline-variant/50 bg-surface px-3 py-2 text-sm text-on-surface outline-none focus:border-primary" />
            <button type="submit" className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-on-primary">Search</button>
            <Link href="/search" className="rounded-lg border border-outline-variant/30 bg-surface-container px-4 py-2 text-sm font-semibold text-on-surface">Clear</Link>
          </form>
          {query.length > 0 && query.length < 2 ? (
            <p className="m-0 text-sm text-on-surface-variant">Enter at least two characters to search.</p>
          ) : null}
          {query.length >= 2 ? (
            <section aria-labelledby="search-results-heading" className="flex flex-col gap-space-md">
              <h2 id="search-results-heading" className="m-0 text-lg font-bold text-on-surface">Matches ({results.length})</h2>
              <nav aria-label="Continue searching queues" className="flex flex-wrap gap-4 text-sm text-primary">
                {hasPermission(roles, "adminBookingsRead") && <Link href={`/bookings?search=${encodeURIComponent(query)}`}>All matching bookings</Link>}
                {hasPermission(roles, "adminProviderApplicationsRead") && <Link href={`/providers?search=${encodeURIComponent(query)}`}>All matching providers</Link>}
                {hasPermission(roles, "adminComplaintsRead") && <Link href={`/support?search=${encodeURIComponent(query)}`}>All matching complaints</Link>}
                {hasPermission(roles, "adminGuaranteesRead") && <Link href={`/guarantees?search=${encodeURIComponent(query)}`}>All matching claims</Link>}
              </nav>
              {results.length > 0 ? (
                <ul className="m-0 list-none divide-y divide-outline-variant/20 rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-0">
                  {results.map((item, index) => (
                    <li key={`${item.href}-${index}`} className="p-4">
                      <span className="inline-block rounded-md bg-surface-container px-2 py-0.5 text-xs font-semibold text-on-surface-variant">{item.label}</span>
                      <p className="mt-2 mb-1 text-sm font-medium text-on-surface">{item.value}</p>
                      <Link href={item.href} className="text-sm font-semibold text-primary hover:underline">Open record</Link>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="m-0 text-sm text-on-surface-variant">No records matched {query}.</p>
              )}
            </section>
          ) : null}
        </div>
      </div>
    </AdminShell>
  );
}
