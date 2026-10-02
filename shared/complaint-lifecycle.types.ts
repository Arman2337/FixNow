/**
 * The complaint lifecycle, in one place.
 *
 * SEC-011. `updateComplaintStatus` assigned `complaint.status = status` with no
 * check on the current value, so any of the five statuses could be moved to any
 * other: a `CLOSED` complaint could be reopened as `OPEN` with no reason, a
 * `RESOLVED` complaint could be pushed to `ESCALATED`, and a complaint could be
 * walked backwards through `IN_REVIEW`. Every one of those wrote a row to
 * `complaint_audit`, so the audit log faithfully recorded a sequence of
 * transitions that the product does not permit — which makes the audit trail
 * evidence of the bug rather than a control against it.
 *
 * The booking lifecycle already solved this properly
 * (`shared/booking-lifecycle.types.ts`): a single source of truth, an explicit
 * transition table, and terminal states that are terminal. This file follows
 * that shape rather than inventing a second idiom, so both state machines in
 * the product read the same way.
 */
export enum ComplaintStatus {
  OPEN = 'OPEN',
  IN_REVIEW = 'IN_REVIEW',
  ESCALATED = 'ESCALATED',
  RESOLVED = 'RESOLVED',
  CLOSED = 'CLOSED',
}

export const VALID_COMPLAINT_TRANSITIONS: Readonly<
  Record<ComplaintStatus, readonly ComplaintStatus[]>
> = {
  // Freshly filed, nothing has happened to it yet. `RESOLVED` is reachable
  // directly from here because plenty of claims are self-evident (a provider
  // who never arrived) and forcing an agent through `IN_REVIEW` first would
  // only produce a status change with no decision behind it.
  [ComplaintStatus.OPEN]: [
    ComplaintStatus.IN_REVIEW,
    ComplaintStatus.ESCALATED,
    ComplaintStatus.RESOLVED,
    ComplaintStatus.CLOSED,
  ],
  // A support agent has picked it up.
  [ComplaintStatus.IN_REVIEW]: [
    ComplaintStatus.ESCALATED,
    ComplaintStatus.RESOLVED,
    ComplaintStatus.CLOSED,
  ],
  // Raised past the front line. Can still be resolved, and can still be closed.
  [ComplaintStatus.ESCALATED]: [
    ComplaintStatus.RESOLVED,
    ComplaintStatus.CLOSED,
  ],
  // An outcome was decided. From here only closure remains — reopening a
  // resolved complaint is the case that makes the audit log worthless, because
  // the customer was already told the matter was settled.
  [ComplaintStatus.RESOLVED]: [ComplaintStatus.CLOSED],
  // Terminal.
  [ComplaintStatus.CLOSED]: [],
};

/**
 * Statuses that require the agent to record why, so "resolved" is never an
 * unexplained state handed to a customer.
 */
export const COMPLAINT_STATUSES_REQUIRING_NOTES: ReadonlySet<ComplaintStatus> =
  new Set([ComplaintStatus.RESOLVED, ComplaintStatus.CLOSED]);

export function isValidComplaintTransition(
  from: ComplaintStatus,
  to: ComplaintStatus,
): boolean {
  return VALID_COMPLAINT_TRANSITIONS[from].includes(to);
}

export function isTerminalComplaintStatus(status: ComplaintStatus): boolean {
  return VALID_COMPLAINT_TRANSITIONS[status].length === 0;
}