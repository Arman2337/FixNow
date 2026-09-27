import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listClaims } from "@/features/guarantees/api";
import { listBookings, listComplaints } from "@/features/operations/api";
import { listProviderApplications } from "@/features/providers/api";

const bookingRoles = ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"];
const providerRoles = ["provider_reviewer", "operations_administrator", "auditor"];
const complaintRoles = ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"];

function hasRole(roles: readonly string[], allowed: readonly string[]) {
  return roles.some((role) => allowed.includes(role));
}

function textResult(label: string, value: string, href: string) {
  return { label, value, href };
}

export default async function SearchPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const query = (await searchParams).q?.trim() ?? "";
  const roles = session.session.roles;
  const normalized = query.toLowerCase();
  const results: { label: string; value: string; href: string }[] = [];

  if (query.length >= 2) {
    if (hasRole(roles, bookingRoles)) {
      const bookings = await requireManagementResult(await listBookings(query));
      results.push(...bookings.items.map((booking) => textResult("Booking", `${booking.id} · ${booking.status} · ${booking.description}`, `/bookings?search=${encodeURIComponent(query)}`)));
    }
    if (hasRole(roles, providerRoles)) {
      const providers = await requireManagementResult(await listProviderApplications(query));
      results.push(...providers.items.map((provider) => textResult("Provider", `${provider.displayName ?? provider.id} · ${provider.status}`, `/providers/${provider.id}`)));
    }
    if (hasRole(roles, complaintRoles)) {
      const complaints = await requireManagementResult(await listComplaints());
      results.push(...complaints.filter((complaint) => `${complaint.id} ${complaint.category} ${complaint.description}`.toLowerCase().includes(normalized)).map((complaint) => textResult("Complaint", `${complaint.id} · ${complaint.status} · ${complaint.category}`, `/support/${complaint.id}`)));
      const claims = await requireManagementResult(await listClaims());
      results.push(...claims.filter((claim) => `${claim.id} ${claim.bookingId} ${claim.description}`.toLowerCase().includes(normalized)).map((claim) => textResult("Guarantee claim", `${claim.id} · ${claim.status} · ${claim.description}`, `/guarantees/${claim.id}`)));
    }
  }

  return (
    <AdminShell environment={env.appEnvironment} roles={roles} current="Overview Dashboard">
      <div className="w-full p-space-lg lg:p-margin-desktop">
        <div className="mx-auto flex max-w-4xl flex-col gap-space-lg">
          <header>
            <p className="m-0 text-xs font-bold uppercase tracking-wider text-primary">Role-aware command search</p>
            <h1 className="mt-1 text-3xl font-bold tracking-tight text-on-surface">Search operations</h1>
            <p className="mt-2 mb-0 text-sm text-on-surface-variant">Results are limited to records your staff role can access.</p>
          </header>
          <form action="/search" role="search" aria-label="Search operations" className="flex gap-2 rounded-xl border border-outline-variant/30 bg-surface-container-low p-2">
            <label className="sr-only" htmlFor="command-search">Search operations</label>
            <input id="command-search" name="q" defaultValue={query} placeholder="Booking, provider, complaint or claim" className="min-w-0 flex-1 rounded-lg border border-outline-variant/50 bg-surface px-3 py-2 text-sm text-on-surface outline-none focus:border-primary" />
            <button type="submit" className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-on-primary">Search</button>
          </form>
          {query.length < 2 ? (
            <p className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-5 text-sm text-on-surface-variant">Enter at least two characters to search authorized records.</p>
          ) : results.length === 0 ? (
            <p className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-5 text-sm text-on-surface-variant">No authorized records match “{query}”.</p>
          ) : (
            <section aria-labelledby="search-results-heading" className="overflow-hidden rounded-2xl border border-outline-variant/30 bg-surface-container-lowest shadow-sm">
              <h2 id="search-results-heading" className="m-0 border-b border-outline-variant/30 p-4 text-lg font-bold text-on-surface">Results ({results.length})</h2>
              <div className="divide-y divide-outline-variant/20">
                {results.map((result) => (
                  <Link key={`${result.label}-${result.value}`} href={result.href} className="block p-4 transition-colors hover:bg-surface-container/60">
                    <span className="text-xs font-bold uppercase tracking-wider text-primary">{result.label}</span>
                    <span className="mt-1 block text-sm text-on-surface">{result.value}</span>
                  </Link>
                ))}
              </div>
            </section>
          )}
        </div>
      </div>
    </AdminShell>
  );
}
