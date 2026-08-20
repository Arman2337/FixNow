import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listBookings } from "@/features/operations/api";
import { StatusBadge } from "@/features/status-badge";

const statuses = ["", "REQUESTED", "ASSIGNED", "EN_ROUTE", "IN_PROGRESS", "COMPLETED", "CANCELLED"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

export default async function BookingsPage({ searchParams }: { searchParams: Promise<{ search?: string; status?: string; cursor?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const params = await searchParams;
  const page = await requireManagementResult(await listBookings(params.search, params.status, params.cursor));
  return <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Bookings">
    <header className="border-b border-[var(--color-border-default)] pb-6"><p className="m-0 text-sm font-semibold text-[var(--color-primary)]">Booking operations</p><h1 className="mt-2 mb-0 text-3xl font-bold">Bookings</h1><p className="mt-2 mb-0 text-[var(--color-text-secondary)]">Find service requests, check their state, and inspect the audit trail.</p></header>
    <form role="search" className="mt-6 grid gap-3 sm:grid-cols-[1fr_14rem_auto_auto]"><label className="sr-only" htmlFor="booking-search">Search bookings</label><input id="booking-search" name="search" defaultValue={params.search} placeholder="Search booking, customer, or provider" className="min-h-12 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4"/><label className="sr-only" htmlFor="booking-status">Status</label><select id="booking-status" name="status" defaultValue={params.status ?? ""} className="min-h-12 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4">{statuses.map((status) => <option key={status} value={status}>{status ? status.replaceAll("_", " ") : "All statuses"}</option>)}</select><button className="min-h-12 rounded-xl bg-[var(--color-primary)] px-5 font-semibold text-[var(--color-on-primary)]">Filter</button><Link href="/bookings" className="inline-flex min-h-12 items-center justify-center rounded-xl border border-[var(--color-border-strong)] px-5 font-semibold">Clear</Link></form>
    <section aria-label="Booking results" className="mt-6 grid gap-4">{page.items.length ? page.items.map((booking) => <article key={booking.id} className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5"><div className="flex items-start justify-between gap-4"><div><p className="m-0 text-sm font-semibold text-[var(--color-text-secondary)]">{booking.serviceCategoryId.replaceAll("_", " ")}</p><h2 className="mt-1 mb-0 text-lg font-semibold">{booking.description}</h2><p className="mt-2 mb-0 text-sm text-[var(--color-text-secondary)]">{booking.providerId ? "Provider assigned" : "Provider matching"} · Updated {new Date(booking.updatedAt).toLocaleString()}</p></div><StatusBadge status={booking.status}/></div><div className="mt-4 flex items-center justify-between gap-3 border-t border-[var(--color-border-default)] pt-3"><p className="m-0 text-xs text-[var(--color-text-muted)]">Booking #{shortId(booking.id)}</p><Link href={`/bookings/${booking.id}`} className="inline-flex min-h-11 items-center font-semibold text-[var(--color-primary)]">Open booking</Link></div></article>) : <p className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">No bookings match these filters.</p>}{page.nextCursor ? <Link className="inline-flex min-h-11 w-fit items-center rounded-xl border border-[var(--color-border-strong)] px-4 font-semibold" href={{ pathname: "/bookings", query: { search: params.search, status: params.status, cursor: page.nextCursor } }}>Next page</Link> : null}</section>
  </AdminShell>;
}
