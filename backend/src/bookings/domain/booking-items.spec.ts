import { computeBookingTotals } from './booking-items';

describe('computeBookingTotals', () => {
  it('returns null duration when items carry no durations', () => {
    expect(
      computeBookingTotals([
        { id: 'a', name: 'A', quantity: 2, unitPriceMinor: 14900 },
      ]),
    ).toEqual({
      subtotalMinor: 29800,
      gstMinor: 5364,
      totalMinor: 35164,
      estimatedDurationMinutes: null,
    });
  });

  it('ignores client-supplied extras by only summing known fields', () => {
    const items = [
      { id: 'a', name: 'A', quantity: 1, unitPriceMinor: 9900, durationMinutes: 25 },
    ];
    expect(computeBookingTotals(items).totalMinor).toBe(11682);
  });
});
