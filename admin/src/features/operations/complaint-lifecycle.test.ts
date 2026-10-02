import { describe, expect, it } from 'vitest';
import {
  COMPLAINT_STATUSES_REQUIRING_NOTES,
  VALID_COMPLAINT_TRANSITIONS,
  isTerminalComplaintStatus,
  nextComplaintStatuses,
  type ComplaintStatus,
} from './complaint-lifecycle';

/**
 * SEC-011. The admin status dropdown used to list all five statuses for every
 * complaint. The backend had no transition table either, so that list was
 * accurate — which is the problem: an agent could submit a move the product
 * does not permit, including reopening a complaint the customer had already been
 * told was resolved.
 *
 * These assertions pin the admin's option list to the backend's table, so the
 * console cannot drift into offering something the server will refuse.
 */
const ALL: ComplaintStatus[] = [
  'OPEN',
  'IN_REVIEW',
  'ESCALATED',
  'RESOLVED',
  'CLOSED',
];

describe('complaint lifecycle (SEC-011)', () => {
  it('declares a transition list for every status', () => {
    expect(Object.keys(VALID_COMPLAINT_TRANSITIONS).sort()).toEqual(
      [...ALL].sort(),
    );
  });

  it('treats CLOSED as the only terminal status', () => {
    expect(ALL.filter(isTerminalComplaintStatus)).toEqual(['CLOSED']);
  });

  it('offers a terminal complaint nothing to move to', () => {
    expect(nextComplaintStatuses('CLOSED')).toEqual([]);
  });

  it('never offers a resolved complaint a way back to open', () => {
    const offered = nextComplaintStatuses('RESOLVED');
    expect(offered).not.toContain('OPEN');
    expect(offered).not.toContain('IN_REVIEW');
  });

  it('never offers the status a complaint already holds', () => {
    for (const status of ALL) {
      expect(nextComplaintStatuses(status)).not.toContain(status);
    }
  });

  it('only ever offers statuses the enum declares', () => {
    for (const status of ALL) {
      for (const offered of nextComplaintStatuses(status)) {
        expect(ALL).toContain(offered);
      }
    }
  });

  it('lets an open complaint reach a terminal one in one step', () => {
    const reachesTerminal = nextComplaintStatuses('OPEN').some(
      isTerminalComplaintStatus,
    );
    expect(reachesTerminal).toBe(true);
  });

  it('requires notes for exactly the outcomes a customer is told about', () => {
    expect(COMPLAINT_STATUSES_REQUIRING_NOTES.has('RESOLVED')).toBe(true);
    expect(COMPLAINT_STATUSES_REQUIRING_NOTES.has('CLOSED')).toBe(true);
    expect(COMPLAINT_STATUSES_REQUIRING_NOTES.has('OPEN')).toBe(false);
    expect(COMPLAINT_STATUSES_REQUIRING_NOTES.has('IN_REVIEW')).toBe(false);
  });
});