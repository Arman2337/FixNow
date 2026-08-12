import { Booking } from './booking.entity';
import { BookingStatus } from '../../../../shared/booking-lifecycle.types';

describe('Booking Entity Domain Logic', () => {
  let booking: Booking;

  beforeEach(() => {
    booking = new Booking();
    booking.status = BookingStatus.REQUESTED;
  });

  it('should allow valid transition from REQUESTED to ASSIGNED', () => {
    expect(() => booking.transitionTo(BookingStatus.ASSIGNED)).not.toThrow();
    expect(booking.status).toBe(BookingStatus.ASSIGNED);
  });

  it('should allow valid transition from REQUESTED to CANCELLED', () => {
    expect(() =>
      booking.transitionTo(BookingStatus.CANCELLED, 'No longer needed'),
    ).not.toThrow();
    expect(booking.status).toBe(BookingStatus.CANCELLED);
    expect(booking.cancellationReason).toBe('No longer needed');
  });

  it('should throw an error when transitioning to CANCELLED without a reason', () => {
    expect(() => booking.transitionTo(BookingStatus.CANCELLED)).toThrow(
      'A cancellation reason must be provided when cancelling a booking',
    );
  });

  it('should reject invalid transition from REQUESTED to COMPLETED', () => {
    expect(() => booking.transitionTo(BookingStatus.COMPLETED)).toThrow(
      'Invalid transition from REQUESTED to COMPLETED',
    );
  });

  it('should allow the full happy path lifecycle', () => {
    booking.transitionTo(BookingStatus.ASSIGNED);
    booking.transitionTo(BookingStatus.EN_ROUTE);
    booking.transitionTo(BookingStatus.IN_PROGRESS);
    booking.transitionTo(BookingStatus.COMPLETED);
    expect(booking.status).toBe(BookingStatus.COMPLETED);
  });

  it('should not allow transitions from CANCELLED', () => {
    booking.status = BookingStatus.CANCELLED;
    expect(() => booking.transitionTo(BookingStatus.REQUESTED)).toThrow(
      'Invalid transition from CANCELLED to REQUESTED',
    );
  });

  it('should not allow transitions from COMPLETED', () => {
    booking.status = BookingStatus.COMPLETED;
    expect(() => booking.transitionTo(BookingStatus.REQUESTED)).toThrow(
      'Invalid transition from COMPLETED to REQUESTED',
    );
  });
});
