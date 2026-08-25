import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { reviewSignalAction } from "@/features/trust/actions";
import { listSignals } from "@/features/trust/api";
import type { TrustSignalSummary } from "@/features/trust/types";

const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

const severityTone: Record<string, string> = {
  LOW: "text-[var(--color-text-secondary)] border-[var(--color-border-default)]",
  MEDIUM: "text-[var(--color-warning)] border-[var(--color-warning)]",
  HIGH: "text-[var(--color-danger)] border-[var(--color-danger)]",
};

const resultMessages: Record<string, string> = {
  reviewed: "Signal marked reviewed.",
  dismissed: "Signal dismissed.",
  stale: "The signal changed before your decision was saved. Refresh and try again.",
  failed: "The action could not be completed.",
};

const ruleLabels: Record<string, string> = {
  "provider-cancellation-frequency-v1": "Provider cancellations",
  "provider-complaint-frequency-v1": "Complaints about provider",
  "customer-cancellation-frequency-v1": "Customer cancellations",
  "provider-refund-frequency-v1": "Refunds on provider bookings",
};

export default async function TrustPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; result?: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");

  const params = await searchParams;
  let signals = await requireManagementResult(await listSignals());
  if (params.status === "OPEN") signals = signals.filter((signal) => signal.status === "OPEN");

  const result = params.result ? resultMessages[params.result] : undefined;

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Trust">
      <header className="border-b border-[var(--color-border-default)] pb-6">
        <p className="m-0 text-sm font-semibold uppercase tracking-[0.08em] text-[var(--color-primary)]">
          Trust &amp; Safety operations
        </p>
        <h1 className="mt-2 mb-0 text-3xl font-bold">Review Signals</h1>
        <p className="mt-2 mb-0 max-w-2xl text-[var(--color-text-secondary)]">
          Advisory patterns raised by deterministic rules. Every signal is
          evidence for a human decision — nothing here enforces anything by
          itself.
        </p>
      </header>

      {result ? (
        <p role="status" className="mt-4 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4 py-3 text-sm">
          {result}
        </p>
      ) : null}

      <form role="search" className="mt-6 flex items-end gap-3">
        <label className="sr-only" htmlFor="trust-status">Signal status</label>
        <select
          id="trust-status"
          name="status"
          defaultValue={params.status ?? ""}
          className="min-h-12 rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4"
        >
          <option value="">All statuses</option>
          <option value="OPEN">Open only</option>
        </select>
        <button className="min-h-12 rounded-xl bg-[var(--color-primary)] px-5 font-semibold text-[var(--color-on-primary)]">
          Filter
        </button>
      </form>

      <section aria-label="Trust review queue" className="mt-6 grid gap-4">
        {signals.length ? (
          signals.map((signal) => <SignalCard key={signal.id} signal={signal} />)
        ) : (
          <div className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-6">
            <h2 className="m-0 text-lg font-semibold">No trust signals</h2>
            <p className="mt-2 mb-0 text-[var(--color-text-secondary)]">
              Nothing has crossed an advisory threshold{params.status === "OPEN" ? " among open signals" : ""}. This queue fills only when the rules observe a pattern.
            </p>
          </div>
        )}
      </section>
    </AdminShell>
  );
}

function SignalCard({ signal }: { signal: TrustSignalSummary }) {
  return (
    <article className="rounded-2xl border border-[var(--color-border-default)] bg-[var(--color-surface-primary)] p-5">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="m-0 text-sm font-semibold">
            {ruleLabels[signal.ruleCode] ?? signal.ruleCode}
          </p>
          <p className="mt-1 mb-0 max-w-2xl text-sm text-[var(--color-text-secondary)]">
            {signal.evidenceSummary}
          </p>
          <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-[var(--color-text-muted)]">
            <span>{signal.subjectType.toLowerCase()} #{shortId(signal.subjectId)}</span>
            <span>window {signal.windowStart}</span>
            <span>Raised {new Date(signal.createdAt).toLocaleDateString()}</span>
          </div>
        </div>
        <span
          className={`inline-flex min-h-7 items-center rounded-full border px-3 text-xs font-semibold ${severityTone[signal.severity] ?? severityTone.LOW}`}
        >
          {signal.severity}
        </span>
      </div>
      {signal.status === "OPEN" ? (
        <div className="mt-4 flex gap-3">
          <form action={reviewSignalAction}>
            <input type="hidden" name="id" value={signal.id} />
            <input type="hidden" name="status" value="REVIEWED" />
            <button className="min-h-11 rounded-xl bg-[var(--color-primary)] px-5 font-semibold text-[var(--color-on-primary)]">
              Mark reviewed
            </button>
          </form>
          <form action={reviewSignalAction}>
            <input type="hidden" name="id" value={signal.id} />
            <input type="hidden" name="status" value="DISMISSED" />
            <button className="min-h-11 rounded-xl border border-[var(--color-border-default)] px-5 font-semibold">
              Dismiss
            </button>
          </form>
        </div>
      ) : (
        <p className="mt-4 mb-0 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
          {signal.status === "REVIEWED" ? "Reviewed" : "Dismissed"}
        </p>
      )}
    </article>
  );
}
