import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { reviewSignalAction, moderateReviewAction, moderatePhotoAction } from "@/features/trust/actions";
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
  "review-moderated": "Review moderation decision applied successfully.",
  "photo-moderated": "Review photo moderation decision applied successfully.",
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
  searchParams: Promise<{ status?: string; result?: string; page?: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  if (!session.session.roles.some((r) => r === "trust_safety_reviewer" || r === "operations_administrator")) {
    redirect("/unauthorized");
  }

  const params = await searchParams;
  const pageNumber = Math.max(1, parseInt(params.page ?? "1", 10));
  const pageSize = 10;
  const offset = (pageNumber - 1) * pageSize;

  const allSignals = await requireManagementResult(await listSignals(pageSize + 1, offset));
  const hasNextPage = allSignals.length > pageSize;
  const pagedSignals = allSignals.slice(0, pageSize);

  let filtered = pagedSignals;
  if (params.status === "OPEN") filtered = filtered.filter((signal) => signal.status === "OPEN");

  const result = params.result ? resultMessages[params.result] : undefined;
  
  const highSeverityCount = filtered.filter((s) => s.severity === "HIGH" && s.status === "OPEN").length;
  const mediumSeverityCount = filtered.filter((s) => s.severity === "MEDIUM" && s.status === "OPEN").length;

  return (
    <AdminShell
      environment={env.appEnvironment}
      roles={session.session.roles}
      email={session.session.email}
      displayName={session.session.displayName}
      current="Trust & Safety"
    >
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-space-md bg-surface-container-lowest p-space-lg rounded-xl shadow-sm border border-outline-variant/30">
            <div className="flex flex-col gap-space-xs max-w-3xl">
              <div className="flex items-center gap-space-sm">
                <span className="inline-flex items-center gap-1.5 rounded-full bg-error-container px-2.5 py-1 font-label-sm text-label-sm tracking-wide text-on-error-container">
                  <span className="h-2 w-2 rounded-full bg-error" aria-hidden="true" />
                  <span className="font-data-mono text-data-mono text-error">Rule-based review queue</span>
                </span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-2">Trust & Safety Moderation</h1>
              <p className="font-body-md text-body-md text-on-surface-variant">Review rule-based trust signals and moderate ratings and review evidence.</p>
            </div>
            {result && (
              <div className="px-4 py-2 rounded-lg bg-surface-container-highest text-on-surface font-label-sm font-bold border border-outline-variant/30">
                {result}
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-space-md">
            <div className="flex flex-col justify-between p-space-md rounded-xl bg-surface-container-lowest shadow-sm hover:shadow-md transition-shadow relative overflow-hidden border border-outline-variant/20">
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
            <div className="flex flex-col justify-between p-space-md rounded-xl bg-surface-container-lowest shadow-sm hover:shadow-md transition-shadow relative overflow-hidden border border-outline-variant/20">
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

          <form role="search" aria-label="Trust signal filters" className="flex items-center gap-3">
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
            {filtered.length ? (
              filtered.map((signal) => <SignalCard key={signal.id} signal={signal} />)
            ) : (
              <div className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-8 text-center flex flex-col items-center gap-4">
                <span className="material-symbols-outlined text-outline text-5xl">shield</span>
                <div>
                  <h2 className="m-0 font-headline-sm text-headline-sm font-bold text-on-surface">No trust signals</h2>
                  <p className="mt-2 mb-0 font-body-md text-on-surface-variant">
                    Nothing has crossed an advisory threshold{params.status === "OPEN" ? " among open signals" : ""}. This queue fills only when rules observe a pattern.
                  </p>
                </div>
              </div>
            )}

            <div className="flex items-center justify-between border-t border-outline-variant/20 pt-4 mt-2">
              <div>
                {pageNumber > 1 ? (
                  <Link
                    href={{ pathname: "/trust", query: { status: params.status, page: String(pageNumber - 1) } }}
                    className="px-4 py-2 rounded-xl border border-outline-variant/40 bg-surface-container-low text-on-surface font-label-md text-sm font-semibold hover:bg-surface-container transition-colors inline-flex items-center gap-1"
                  >
                    <span className="material-symbols-outlined text-[16px]">arrow_back</span>
                    <span>Previous page</span>
                  </Link>
                ) : <div />}
              </div>
              <span className="font-body-sm text-sm text-on-surface-variant">Page {pageNumber}</span>
              <div>
                {hasNextPage ? (
                  <Link
                    href={{ pathname: "/trust", query: { status: params.status, page: String(pageNumber + 1) } }}
                    className="px-4 py-2 rounded-xl bg-primary text-on-primary font-label-md text-sm font-semibold hover:bg-primary/90 transition-colors inline-flex items-center gap-1"
                  >
                    <span>Next page</span>
                    <span className="material-symbols-outlined text-[16px]">arrow_forward</span>
                  </Link>
                ) : <div />}
              </div>
            </div>
          </section>

          {/* GAP-57: Review & Photo Moderation Controls */}
          <section aria-labelledby="review-moderation-heading" className="rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-space-lg shadow-sm mt-4">
            <div className="flex items-center gap-2 mb-space-md border-b border-outline-variant/20 pb-space-sm">
              <span className="material-symbols-outlined text-primary text-2xl">rate_review</span>
              <div>
                <h2 id="review-moderation-heading" className="font-headline-sm text-headline-sm font-bold text-on-surface">Review & Photo Moderation</h2>
                <p className="text-body-sm text-on-surface-variant">Execute moderation actions on customer reviews and submitted job proof photos.</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-space-lg">
              {/* Review Moderation */}
              <div className="p-space-md rounded-xl bg-surface-container-low border border-outline-variant/30">
                <h3 className="font-label-lg font-bold text-on-surface mb-3 flex items-center gap-2">
                  <span className="material-symbols-outlined text-primary text-[20px]">edit_note</span>
                  Moderate Review Text
                </h3>
                <form action={moderateReviewAction} className="flex flex-col gap-3">
                  <label className="flex flex-col gap-1">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Review ID</span>
                    <input required name="reviewId" placeholder="UUID of the review" className="py-2 px-3 rounded-lg border border-outline-variant/50 bg-surface text-sm text-on-surface" />
                  </label>
                  <label className="flex flex-col gap-1">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Target Status</span>
                    <select name="moderationStatus" className="py-2 px-3 rounded-lg border border-outline-variant/50 bg-surface text-sm text-on-surface">
                      <option value="PUBLISHED">PUBLISHED (Make visible)</option>
                      <option value="HIDDEN">HIDDEN (Hide from public)</option>
                      <option value="FLAGGED">FLAGGED (Flag for investigation)</option>
                    </select>
                  </label>
                  <label className="flex flex-col gap-1">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Reason</span>
                    <input required name="reason" placeholder="e.g. Terms violation or profanity" defaultValue="Content compliance review" className="py-2 px-3 rounded-lg border border-outline-variant/50 bg-surface text-sm text-on-surface" />
                  </label>
                  <button type="submit" className="mt-2 py-2 px-4 rounded-lg bg-primary text-on-primary font-label-md font-semibold hover:bg-primary/90 transition-colors">
                    Apply Review Action
                  </button>
                </form>
              </div>

              {/* Photo Moderation */}
              <div className="p-space-md rounded-xl bg-surface-container-low border border-outline-variant/30">
                <h3 className="font-label-lg font-bold text-on-surface mb-3 flex items-center gap-2">
                  <span className="material-symbols-outlined text-primary text-[20px]">photo_camera</span>
                  Moderate Review Photo
                </h3>
                <form action={moderatePhotoAction} className="flex flex-col gap-3">
                  <label className="flex flex-col gap-1">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Photo ID</span>
                    <input required name="photoId" placeholder="UUID of the photo" className="py-2 px-3 rounded-lg border border-outline-variant/50 bg-surface text-sm text-on-surface" />
                  </label>
                  <label className="flex flex-col gap-1">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Decision</span>
                    <select name="photoStatus" className="py-2 px-3 rounded-lg border border-outline-variant/50 bg-surface text-sm text-on-surface">
                      <option value="APPROVED">APPROVED (Valid proof)</option>
                      <option value="REJECTED">REJECTED (Blurry or fraudulent)</option>
                    </select>
                  </label>
                  <label className="flex flex-col gap-1">
                    <span className="font-label-sm font-semibold uppercase text-secondary">Reason</span>
                    <input required name="reason" placeholder="e.g. Inadequate resolution or irrelevant" defaultValue="Image verification review" className="py-2 px-3 rounded-lg border border-outline-variant/50 bg-surface text-sm text-on-surface" />
                  </label>
                  <button type="submit" className="mt-2 py-2 px-4 rounded-lg bg-primary text-on-primary font-label-md font-semibold hover:bg-primary/90 transition-colors">
                    Apply Photo Action
                  </button>
                </form>
              </div>
            </div>
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
