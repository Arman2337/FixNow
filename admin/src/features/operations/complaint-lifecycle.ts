import {
  ComplaintStatus as SharedComplaintStatus,
  VALID_COMPLAINT_TRANSITIONS,
  COMPLAINT_STATUSES_REQUIRING_NOTES as requiringNotes,
} from "../../../../shared/complaint-lifecycle.types";

export type ComplaintStatus = `${SharedComplaintStatus}`;
export { VALID_COMPLAINT_TRANSITIONS };
export const COMPLAINT_STATUSES_REQUIRING_NOTES = requiringNotes as ReadonlySet<ComplaintStatus>;
export function nextComplaintStatuses(status: ComplaintStatus): readonly ComplaintStatus[] {
  return VALID_COMPLAINT_TRANSITIONS[status];
}
export function isTerminalComplaintStatus(status: ComplaintStatus): boolean {
  return nextComplaintStatuses(status).length === 0;
}
