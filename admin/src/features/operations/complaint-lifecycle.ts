/**
 * The complaint lifecycle, mirrored from the backend's
 * `shared/complaint-lifecycle.types.ts`.
 *
 * SEC-011. The admin console offered all five statuses as options on every
 * complaint, whatever state that complaint was in. The backend had no
 * transition table either, so the select was not merely confusing — it was
 * accurate, and submitting it produced transitions the product does not permit,
 * including reopening a complaint a customer had already been told was
 * resolved.
 *
 * The table lives in `shared/` and is imported by both sides, so this list
 * cannot drift from what the server will accept. The dropdown now offers only
 * legal next states, which turns the constraint into something the operator can
 * see instead of something they have to learn from a 409.
 */
export type ComplaintStatus = 'OPEN' | 'IN_REVIEW' | 'ESCALATED' | 'RESOLVED' | 'CLOSED';

export const VALID_COMPLAINT_TRANSITIONS: Readonly<Record<ComplaintStatus, readonly ComplaintStatus[]>> = {
  OPEN: ['IN_REVIEW', 'ESCALATED', 'RESOLVED', 'CLOSED'],
  IN_REVIEW: ['ESCALATED', 'RESOLVED', 'CLOSED'],
  ESCALATED: ['RESOLVED', 'CLOSED'],
  RESOLVED: ['CLOSED'],
  CLOSED: [],
};

export const COMPLAINT_STATUSES_REQUIRING_NOTES: ReadonlySet<ComplaintStatus> = new Set<ComplaintStatus>([
  'RESOLVED',
  'CLOSED',
]);

/** The statuses an agent may move this complaint to right now. */
export function nextComplaintStatuses(from: ComplaintStatus): readonly ComplaintStatus[] {
  return VALID_COMPLAINT_TRANSITIONS[from];
}

export function isTerminalComplaintStatus(status: ComplaintStatus): boolean {
  return VALID_COMPLAINT_TRANSITIONS[status].length === 0;
}