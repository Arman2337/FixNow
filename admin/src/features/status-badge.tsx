const labels: Record<string, string> = {
  unverified: "Unverified", under_review: "Under review", approved: "Approved",
  rejected: "Rejected", resubmission_requested: "Resubmission requested",
  reviewed: "Reviewed", dismissed: "Dismissed", active: "Active", pending_verification: "Pending verification", restricted: "Restricted", suspended: "Suspended",
};

export function StatusBadge({ status }: { status: string }) {
  const normalized = status.toLowerCase();
  const tone = ["approved", "active", "completed", "resolved", "reviewed"].includes(normalized) ? "text-[var(--color-primary)] border-[var(--color-primary)]" : ["rejected", "suspended", "cancelled", "escalated", "restricted"].includes(normalized) ? "text-[var(--color-danger)] border-[var(--color-danger)]" : "text-[var(--color-warning)] border-[var(--color-warning)]";
  return <span className={`inline-flex min-h-7 items-center rounded-full border px-3 text-xs font-semibold ${tone}`}>{labels[status] ?? labels[normalized] ?? status.replaceAll("_", " ")}</span>;
}
