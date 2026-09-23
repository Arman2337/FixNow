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
  LOW: "bg-surface-container text-on-surface-variant",
  MEDIUM: "bg-tertiary-container text-on-tertiary-container",
  HIGH: "bg-error-container text-on-error-container",
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
  
  const highSeverityCount = signals.filter((s) => s.severity === "HIGH" && s.status === "OPEN").length;
  const mediumSeverityCount = signals.filter((s) => s.severity === "MEDIUM" && s.status === "OPEN").length;

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Trust & Safety">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-space-md bg-surface-container-lowest p-space-lg rounded-xl shadow-sm">
            <div className="flex flex-col gap-space-xs max-w-3xl">
              <div className="flex items-center gap-space-sm">
                <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-error-container text-on-error-container font-label-sm text-label-sm tracking-wide">
                  <span className="w-2 h-2 rounded-full bg-error animate-pulse"></span>
                  <span className="font-data-mono text-data-mono text-error">BUILD 4.19-SEC</span>
                </span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-2">Trust & Safety Moderation</h1>
              <p className="font-body-md text-body-md text-on-surface-variant">Real-time review sentiment analysis, proof photo compliance, and fraud pattern detection.</p>
            </div>
            {result && (
              <div className="px-4 py-2 rounded-lg bg-surface-container-highest text-on-surface font-label-sm font-bold">
                {result}
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-space-md">
            <div className="flex flex-col justify-between p-space-md rounded-xl bg-surface-container-lowest shadow-sm hover:shadow-md transition-shadow relative overflow-hidden">
              <div className="absolute -right-6 -bottom-6 w-24 h-24 rounded-full bg-error/5 pointer-events-none"></div>
              <div className="flex items-start justify-between">
                <div className="flex flex-col">
                  <span className="font-label-sm text-label-sm uppercase text-secondary">High Risk Queue</span>
                  <span className="font-headline-lg text-headline-lg text-error mt-1">{highSeverityCount} Pending</span>
                </div>
                <div className="w-10 h-10 rounded-xl bg-error-container text-on-error-container flex items-center justify-center">
                  <span className="material-symbols-outlined text-xl">gavel</span>
                </div>
              </div>
            </div>
            <div className="flex flex-col justify-between p-space-md rounded-xl bg-surface-container-lowest shadow-sm hover:shadow-md transition-shadow relative overflow-hidden">
              <div className="absolute -right-6 -bottom-6 w-24 h-24 rounded-full bg-tertiary/5 pointer-events-none"></div>
              <div className="flex items-start justify-between">
                <div className="flex flex-col">
                  <span className="font-label-sm text-label-sm uppercase text-secondary">Medium Risk Queue</span>
                  <span className="font-headline-lg text-headline-lg text-tertiary mt-1">{mediumSeverityCount} Pending</span>
                </div>
                <div className="w-10 h-10 rounded-xl bg-tertiary-container text-on-tertiary-container flex items-center justify-center">
                  <span className="material-symbols-outlined text-xl">warning</span>
                </div>
              </div>
            </div>
          </div>

          <form role="search" className="flex items-center gap-3">
            <label className="sr-only" htmlFor="trust-status">Signal status</label>
            <select
              id="trust-status"
              name="status"
              defaultValue={params.status ?? ""}
              className="px-4 py-2.5 rounded-xl border border-outline-variant/50 bg-surface-container-low font-body-sm text-body-sm text-on-surface focus:outline-none focus:border-primary transition-all"
            >
              <option value="">All statuses</option>
              <option value="OPEN">Open only</option>
            </select>
            <button className="px-5 py-2.5 rounded-xl bg-primary text-on-primary font-label-md text-label-md font-semibold hover:bg-primary-container transition-colors shadow-sm">
              Filter
            </button>
          </form>

          <section aria-label="Trust review queue" className="flex flex-col gap-space-lg">
            {signals.length ? (
              signals.map((signal) => <SignalCard key={signal.id} signal={signal} />)
            ) : (
              <div className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-8 text-center flex flex-col items-center gap-4">
                <span className="material-symbols-outlined text-outline text-5xl">shield</span>
                <div>
                  <h2 className="m-0 font-headline-sm text-headline-sm font-bold text-on-surface">No active trust signals</h2>
                  <p className="mt-2 mb-0 font-body-md text-on-surface-variant">
                    Nothing has crossed an advisory threshold{params.status === "OPEN" ? " among open signals" : ""}. This queue fills only when rules observe a pattern.
                  </p>
                </div>
              </div>
            )}
          </section>

        </div>
      </div>
    </AdminShell>
  );
}

function SignalCard({ signal }: { signal: TrustSignalSummary }) {
  return (
    <div className="p-space-lg rounded-xl bg-surface-container-lowest shadow-sm flex flex-col gap-space-md border border-outline-variant/20 hover:shadow-md transition-all">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-space-sm">
        <div className="flex items-center gap-space-sm">
          <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${severityTone[signal.severity] ?? severityTone.LOW}`}>
            <span className="material-symbols-outlined">{signal.severity === 'HIGH' ? 'gavel' : 'warning'}</span>
          </div>
          <div className="flex flex-col">
            <div className="flex items-center gap-2">
              <span className="font-headline-md text-headline-md text-on-surface">{ruleLabels[signal.ruleCode] ?? signal.ruleCode}</span>
              <span className={`px-2 py-0.5 rounded-full font-label-sm text-label-sm font-semibold ${severityTone[signal.severity] ?? severityTone.LOW}`}>
                {signal.severity} RISK
              </span>
            </div>
            <span className="font-body-sm text-body-sm text-secondary">
              Target: {signal.subjectType} #{shortId(signal.subjectId)}
            </span>
          </div>
        </div>
        <span className="font-data-mono text-data-mono text-on-surface-variant bg-surface-container-low px-2.5 py-1 rounded-md">
          {new Date(signal.createdAt).toLocaleString()}
        </span>
      </div>

      <div className="p-space-md rounded-xl bg-surface-container-low flex flex-col gap-space-xs border border-outline-variant/30">
        <span className="font-label-sm text-label-sm uppercase text-secondary font-semibold">Signal Evidence</span>
        <p className="font-body-md text-on-surface mt-1">{signal.evidenceSummary}</p>
        <span className="font-data-mono text-[10px] text-on-surface-variant mt-2">Analysis Window: {signal.windowStart}</span>
      </div>

      {signal.status === "OPEN" ? (
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-end gap-2 pt-space-xs mt-2">
          <form action={reviewSignalAction} className="flex-1 sm:flex-none">
            <input type="hidden" name="id" value={signal.id} />
            <input type="hidden" name="status" value="DISMISSED" />
            <button className="w-full px-4 py-2.5 rounded-lg bg-surface-container hover:bg-surface-container-high text-on-surface font-label-md text-label-md transition-colors border border-outline-variant/30">
              Dismiss Signal
            </button>
          </form>
          <form action={reviewSignalAction} className="flex-1 sm:flex-none">
            <input type="hidden" name="id" value={signal.id} />
            <input type="hidden" name="status" value="REVIEWED" />
            <button className="w-full px-4 py-2.5 rounded-lg bg-primary text-on-primary hover:bg-primary-container font-label-md text-label-md shadow-sm transition-colors">
              Mark as Reviewed
            </button>
          </form>
        </div>
      ) : (
        <div className="flex justify-end pt-space-xs mt-2">
          <span className="font-label-md text-label-md font-bold uppercase tracking-wide text-secondary">
            {signal.status === "REVIEWED" ? "Reviewed" : "Dismissed"}
          </span>
        </div>
      )}
    </div>
  );
}
