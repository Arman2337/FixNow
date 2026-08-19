import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { updateComplaintStatusAction } from "@/features/operations/actions";
import { getComplaint } from "@/features/operations/api";
import { StatusBadge } from "@/features/status-badge";

const labels: Record<string, string> = { 
  updated: "Case status successfully updated.",
  failed: "The action could not be completed."
};

const selectableStatuses = ["OPEN", "IN_REVIEW", "ESCALATED", "RESOLVED", "CLOSED"];

export default async function ComplaintDetailPage({ params, searchParams }: { params: Promise<{ complaintId: string }>; searchParams: Promise<{ result?: string }> }) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const { complaintId } = await params;
  const response = await getComplaint(complaintId);
  if (!response.ok && response.status === 404) notFound();
  const complaint = await requireManagementResult(response);
  const { result } = await searchParams;
  
  const canIntervene = session.session.roles.some((role) => role === "support_agent" || role === "trust_safety_reviewer" || role === "operations_administrator");
  
  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Support">
      <Link href="/support" className="font-semibold text-[var(--color-primary)]">← Back to cases</Link>
      
      <header className="mt-5 border-b border-[var(--color-border-default)] pb-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="m-0 text-sm font-semibold text-[var(--color-primary)]">Support case detail</p>
            <h1 className="mt-2 mb-0 break-all font-mono text-2xl">{complaint.id}</h1>
          </div>
          <StatusBadge status={complaint.status} />
        </div>
      </header>
      
      {result ? (
        <p role="status" className="mt-5 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] p-3">
          {labels[result] ?? result}
        </p>
      ) : null}
      
      <section aria-labelledby="summary" className="mt-6 rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
        <h2 id="summary" className="m-0 text-xl font-semibold">Summary</h2>
        <dl className="mt-4 grid gap-4 sm:grid-cols-2">
          <div>
            <dt className="text-sm text-[var(--color-text-muted)]">Submitter ID</dt>
            <dd className="m-0 break-all font-mono text-sm">{complaint.submitterId}</dd>
          </div>
          <div>
            <dt className="text-sm text-[var(--color-text-muted)]">Target Role</dt>
            <dd className="m-0 break-all font-mono text-sm">{complaint.targetRole}</dd>
          </div>
          <div>
            <dt className="text-sm text-[var(--color-text-muted)]">Target ID</dt>
            <dd className="m-0 break-all font-mono text-sm">{complaint.targetId ?? "N/A"}</dd>
          </div>
          <div>
            <dt className="text-sm text-[var(--color-text-muted)]">Booking ID</dt>
            <dd className="m-0 break-all font-mono text-sm">
              {complaint.bookingId ? (
                <Link href={`/bookings/${complaint.bookingId}`} className="text-[var(--color-primary)] hover:underline">
                  {complaint.bookingId}
                </Link>
              ) : "N/A"}
            </dd>
          </div>
          <div>
            <dt className="text-sm text-[var(--color-text-muted)]">Category</dt>
            <dd className="m-0 text-sm font-semibold">{complaint.category}</dd>
          </div>
          <div>
            <dt className="text-sm text-[var(--color-text-muted)]">Created At</dt>
            <dd className="m-0">{new Date(complaint.createdAt).toLocaleString()}</dd>
          </div>
        </dl>
        
        <h3 className="mt-5 mb-1 text-sm text-[var(--color-text-muted)]">Description</h3>
        <p className="m-0 whitespace-pre-wrap rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] p-4">{complaint.description}</p>
      </section>

      {complaint.evidence && complaint.evidence.length > 0 ? (
        <section aria-labelledby="evidence" className="mt-6 rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
          <h2 id="evidence" className="m-0 text-xl font-semibold">Evidence</h2>
          <ul className="mt-4 grid list-none gap-3 p-0">
            {complaint.evidence.map((ev) => (
              <li key={ev.id} className="rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] p-4">
                <p className="m-0 text-sm font-semibold">File Type: {ev.fileType}</p>
                <a href={ev.fileUrl} target="_blank" rel="noopener noreferrer" className="mt-1 inline-block text-[var(--color-primary)] hover:underline">
                  View evidence file
                </a>
                {ev.description && <p className="mt-2 mb-0 text-sm">{ev.description}</p>}
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {canIntervene ? (
        <section aria-labelledby="intervene" className="mt-6 rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
          <h2 id="intervene" className="m-0 text-xl font-semibold">Manage Case</h2>
          <p className="mt-2 text-sm">Update the case status and provide resolution notes if resolving.</p>
          
          <form action={updateComplaintStatusAction} className="mt-4 grid gap-4">
            <input type="hidden" name="id" value={complaint.id} />
            
            <div>
              <label htmlFor="status" className="block text-sm font-semibold mb-2">Change Status</label>
              <select id="status" name="status" defaultValue={complaint.status} className="w-full min-h-12 rounded-xl border border-[var(--color-border-strong)] bg-[var(--color-surface-primary)] px-4">
                {selectableStatuses.map(status => (
                  <option key={status} value={status}>{status.replaceAll("_", " ")}</option>
                ))}
              </select>
            </div>

            <div>
              <label htmlFor="resolutionNotes" className="block text-sm font-semibold mb-2">Resolution Notes</label>
              <textarea 
                id="resolutionNotes" 
                name="resolutionNotes" 
                defaultValue={complaint.resolutionNotes ?? ""}
                className="w-full min-h-24 rounded-xl border border-[var(--color-border-strong)] bg-[var(--color-surface-primary)] p-3"
                placeholder="Required when resolving the case..."
              />
            </div>
            
            <button className="min-h-11 w-fit rounded-xl bg-[var(--color-primary)] px-5 font-semibold text-[var(--color-on-primary)] hover:bg-[var(--color-primary-strong)]">
              Save changes
            </button>
          </form>
        </section>
      ) : (
        complaint.resolutionNotes && (
          <section aria-labelledby="resolution" className="mt-6 rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
            <h2 id="resolution" className="m-0 text-xl font-semibold">Resolution Notes</h2>
            <p className="mt-4 m-0 whitespace-pre-wrap rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] p-4">
              {complaint.resolutionNotes}
            </p>
          </section>
        )
      )}
    </AdminShell>
  );
}
