import {
  BookingStatus,
  VALID_BOOKING_TRANSITIONS,
  isValidBookingTransition,
  isTerminalBookingStatus,
} from '../../../shared/booking-lifecycle.types';
import {
  ComplaintStatus,
  VALID_COMPLAINT_TRANSITIONS,
  COMPLAINT_STATUSES_REQUIRING_NOTES,
  isValidComplaintTransition,
  isTerminalComplaintStatus,
} from '../../../shared/complaint-lifecycle.types';
import {
  GuaranteeClaimStatus,
  nextGuaranteeStatuses,
} from '../../../shared/guarantee-lifecycle.types';

describe('Guarantee lifecycle', () => {
  it('defines every status, keeps terminal states closed and prevents backward reviews', () => {
    for (const status of Object.values(GuaranteeClaimStatus)) {
      expect(Array.isArray(nextGuaranteeStatuses(status))).toBe(true);
      expect(nextGuaranteeStatuses(status)).not.toContain(status);
      for (const next of nextGuaranteeStatuses(status)) {
        expect(Object.values(GuaranteeClaimStatus)).toContain(next);
      }
    }
    expect(nextGuaranteeStatuses(GuaranteeClaimStatus.COMPLETED)).toEqual([]);
    expect(nextGuaranteeStatuses(GuaranteeClaimStatus.REJECTED)).toEqual([]);
    expect(nextGuaranteeStatuses(GuaranteeClaimStatus.APPROVED)).toEqual([
      GuaranteeClaimStatus.COMPLETED,
    ]);
    expect(nextGuaranteeStatuses(GuaranteeClaimStatus.IN_REVIEW)).not.toContain(
      GuaranteeClaimStatus.PENDING,
    );
  });
});

describe('Shared State Machine Transition Tables (GAP-86)', () => {
  describe('Booking Lifecycle Transitions', () => {
    it('defines explicit transition rules for every BookingStatus', () => {
      const allStatuses = Object.values(BookingStatus);
      for (const status of allStatuses) {
        expect(VALID_BOOKING_TRANSITIONS[status]).toBeDefined();
        expect(Array.isArray(VALID_BOOKING_TRANSITIONS[status])).toBe(true);
      }
    });

    it('allows valid progressive lifecycle transitions', () => {
      expect(
        isValidBookingTransition(
          BookingStatus.REQUESTED,
          BookingStatus.ASSIGNED,
        ),
      ).toBe(true);
      expect(
        isValidBookingTransition(
          BookingStatus.REQUESTED,
          BookingStatus.CANCELLED,
        ),
      ).toBe(true);

      expect(
        isValidBookingTransition(
          BookingStatus.ASSIGNED,
          BookingStatus.EN_ROUTE,
        ),
      ).toBe(true);
      expect(
        isValidBookingTransition(
          BookingStatus.ASSIGNED,
          BookingStatus.CANCELLED,
        ),
      ).toBe(true);

      expect(
        isValidBookingTransition(
          BookingStatus.EN_ROUTE,
          BookingStatus.IN_PROGRESS,
        ),
      ).toBe(true);
      expect(
        isValidBookingTransition(
          BookingStatus.EN_ROUTE,
          BookingStatus.CANCELLED,
        ),
      ).toBe(true);

      expect(
        isValidBookingTransition(
          BookingStatus.IN_PROGRESS,
          BookingStatus.COMPLETED,
        ),
      ).toBe(true);
      expect(
        isValidBookingTransition(
          BookingStatus.IN_PROGRESS,
          BookingStatus.CANCELLED,
        ),
      ).toBe(true);
    });

    it('rejects illegal skipped or backwards transitions', () => {
      // Skipped transitions
      expect(
        isValidBookingTransition(
          BookingStatus.REQUESTED,
          BookingStatus.IN_PROGRESS,
        ),
      ).toBe(false);
      expect(
        isValidBookingTransition(
          BookingStatus.REQUESTED,
          BookingStatus.COMPLETED,
        ),
      ).toBe(false);
      expect(
        isValidBookingTransition(
          BookingStatus.ASSIGNED,
          BookingStatus.COMPLETED,
        ),
      ).toBe(false);

      // Backwards transitions
      expect(
        isValidBookingTransition(
          BookingStatus.COMPLETED,
          BookingStatus.REQUESTED,
        ),
      ).toBe(false);
      expect(
        isValidBookingTransition(
          BookingStatus.IN_PROGRESS,
          BookingStatus.ASSIGNED,
        ),
      ).toBe(false);
      expect(
        isValidBookingTransition(
          BookingStatus.EN_ROUTE,
          BookingStatus.REQUESTED,
        ),
      ).toBe(false);
      expect(
        isValidBookingTransition(
          BookingStatus.CANCELLED,
          BookingStatus.REQUESTED,
        ),
      ).toBe(false);
    });

    it('identifies COMPLETED and CANCELLED as terminal states', () => {
      expect(isTerminalBookingStatus(BookingStatus.COMPLETED)).toBe(true);
      expect(isTerminalBookingStatus(BookingStatus.CANCELLED)).toBe(true);
      expect(isTerminalBookingStatus(BookingStatus.REQUESTED)).toBe(false);
      expect(isTerminalBookingStatus(BookingStatus.IN_PROGRESS)).toBe(false);
    });
  });

  describe('Complaint Lifecycle Transitions', () => {
    it('defines explicit transition rules for every ComplaintStatus', () => {
      const allStatuses = Object.values(ComplaintStatus);
      for (const status of allStatuses) {
        expect(VALID_COMPLAINT_TRANSITIONS[status]).toBeDefined();
        expect(Array.isArray(VALID_COMPLAINT_TRANSITIONS[status])).toBe(true);
      }
    });

    it('allows valid complaint resolutions and escalations from OPEN', () => {
      expect(
        isValidComplaintTransition(
          ComplaintStatus.OPEN,
          ComplaintStatus.IN_REVIEW,
        ),
      ).toBe(true);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.OPEN,
          ComplaintStatus.ESCALATED,
        ),
      ).toBe(true);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.OPEN,
          ComplaintStatus.RESOLVED,
        ),
      ).toBe(true);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.OPEN,
          ComplaintStatus.CLOSED,
        ),
      ).toBe(true);
    });

    it('allows progression from IN_REVIEW and ESCALATED to terminal or next states', () => {
      expect(
        isValidComplaintTransition(
          ComplaintStatus.IN_REVIEW,
          ComplaintStatus.ESCALATED,
        ),
      ).toBe(true);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.IN_REVIEW,
          ComplaintStatus.RESOLVED,
        ),
      ).toBe(true);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.IN_REVIEW,
          ComplaintStatus.CLOSED,
        ),
      ).toBe(true);

      expect(
        isValidComplaintTransition(
          ComplaintStatus.ESCALATED,
          ComplaintStatus.RESOLVED,
        ),
      ).toBe(true);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.ESCALATED,
          ComplaintStatus.CLOSED,
        ),
      ).toBe(true);
    });

    it('strictly forbids backwards transitions and reopening resolved complaints', () => {
      // Cannot move backwards to OPEN
      expect(
        isValidComplaintTransition(
          ComplaintStatus.IN_REVIEW,
          ComplaintStatus.OPEN,
        ),
      ).toBe(false);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.ESCALATED,
          ComplaintStatus.OPEN,
        ),
      ).toBe(false);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.RESOLVED,
          ComplaintStatus.OPEN,
        ),
      ).toBe(false);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.CLOSED,
          ComplaintStatus.OPEN,
        ),
      ).toBe(false);

      // RESOLVED can only transition to CLOSED
      expect(
        isValidComplaintTransition(
          ComplaintStatus.RESOLVED,
          ComplaintStatus.CLOSED,
        ),
      ).toBe(true);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.RESOLVED,
          ComplaintStatus.IN_REVIEW,
        ),
      ).toBe(false);
      expect(
        isValidComplaintTransition(
          ComplaintStatus.RESOLVED,
          ComplaintStatus.ESCALATED,
        ),
      ).toBe(false);
    });

    it('identifies CLOSED as terminal state', () => {
      expect(isTerminalComplaintStatus(ComplaintStatus.CLOSED)).toBe(true);
      expect(isTerminalComplaintStatus(ComplaintStatus.RESOLVED)).toBe(false);
      expect(isTerminalComplaintStatus(ComplaintStatus.OPEN)).toBe(false);
    });

    it('correctly declares statuses requiring resolution notes', () => {
      expect(
        COMPLAINT_STATUSES_REQUIRING_NOTES.has(ComplaintStatus.RESOLVED),
      ).toBe(true);
      expect(
        COMPLAINT_STATUSES_REQUIRING_NOTES.has(ComplaintStatus.CLOSED),
      ).toBe(true);
      expect(COMPLAINT_STATUSES_REQUIRING_NOTES.has(ComplaintStatus.OPEN)).toBe(
        false,
      );
      expect(
        COMPLAINT_STATUSES_REQUIRING_NOTES.has(ComplaintStatus.IN_REVIEW),
      ).toBe(false);
      expect(
        COMPLAINT_STATUSES_REQUIRING_NOTES.has(ComplaintStatus.ESCALATED),
      ).toBe(false);
    });
  });
});
