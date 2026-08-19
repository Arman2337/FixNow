import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listComplaints } from "@/features/operations/api";
import { StatusBadge } from "@/features/status-badge";

const statuses = ["", "OPEN", "IN_REVIEW", "ESCALATED", "RESOLVED", "CLOSED"];

export default async function SupportPage({ searchParams }: { searchParams: Promise<{ search?: string; status?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const params = await searchParams;
  let complaints = await requireManagementResult(await listComplaints());
  
  if (params.search) {
    const s = params.search.toLowerCase();
    complaints = complaints.filter(c => c.id.toLowerCase().includes(s) || c.submitterId.toLowerCase().includes(s));
  }
  if (params.status) {
    complaints = complaints.filter(c => c.status === params.status);
  }

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Support">
      <header className="border-b border-[var(--color-border-default)] pb-6">
        <p className="m-0 text-sm font-semibold text-[var(--color-primary)]">Trust &amp; Safety operations</p>
        <h1 className="mt-2 mb-0 text-3xl font-bold">Support Cases</h1>
        <p className="mt-2 mb-0 text-[var(--color-text-secondary)]">Search and manage user complaints and issues.</p>
      </header>
      <form role="search" className="mt-6 grid gap-3 sm:grid-cols-[1fr_14rem_auto]">
        <label className="sr-only" htmlFor="support-search">Search cases</label>
        <input id="support-search" name="search" defaultValue={params.search} placeholder="Case ID or Submitter ID" className="min-h-12 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4" />
        <label className="sr-only" htmlFor="support-status">Status</label>
        <select id="support-status" name="status" defaultValue={params.status ?? ""} className="min-h-12 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4">
          {statuses.map((status) => <option key={status} value={status}>{status ? status.replaceAll("_", " ") : "All statuses"}</option>)}
        </select>
        <button className="min-h-12 rounded-xl bg-[var(--color-primary)] px-5 font-semibold text-[var(--color-on-primary)]">Filter</button>
      </form>
      <section aria-label="Support results" className="mt-6 grid gap-4">
        {complaints.length ? complaints.map((complaint) => (
          <article key={complaint.id} className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="m-0 font-mono text-sm">{complaint.id}</h2>
                <p className="mt-1 font-semibold">{complaint.category}</p>
                <p className="mt-2 mb-0 text-sm text-[var(--color-text-secondary)]">Updated {new Date(complaint.updatedAt).toLocaleString()}</p>
              </div>
              <StatusBadge status={complaint.status} />
            </div>
            <Link href={`/support/${complaint.id}`} className="mt-4 inline-flex min-h-11 items-center font-semibold text-[var(--color-primary)]">Open case</Link>
          </article>
        )) : <p className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">No cases found.</p>}
      </section>
    </AdminShell>
  );
}
